import Foundation
import UserNotifications

/// 온라인에서 생긴 일(교환 제안, 마켓 판매, 친구 신청)을 macOS 알림으로 알린다.
///
/// 지금까지는 메뉴바를 열어 개수를 보거나 온라인 창의 알림 탭을 열어야 알 수 있었다. 교환 제안은
/// 72시간이면 닫히는데, 앱을 열어 보지 않으면 온 줄도 모른다.
///
/// 서버가 밀어 주는 푸시가 아니라 앱이 이미 하던 알림 개수 확인에 얹는다. 개수 확인 때 「마지막으로
/// 본 알림 뒤에 새로 온 것」만 받아 와 알린다. 그 위치는 계정마다 기기에 적어 두므로 앱을 다시 켜도
/// 이미 알린 것을 또 알리지 않는다. 처음 켰을 때 쌓여 있던 알림은 알리지 않고 그 뒤부터 센다.
@MainActor
final class OnlineAlerts {
    struct Item: Decodable, Equatable {
        struct Detail: Decodable, Equatable {
            var nickname: String? = nil
            var printing: String? = nil
            var unit_tokens: Int? = nil
        }
        let id: Int
        let kind: String
        let read: Bool
        /// 이 알림이 가리키는 것(교환, 판매 글, 친구 관계)의 서버 번호.
        var target: String? = nil
        var detail: Detail? = nil
    }
    struct Page: Decodable {
        let items: [Item]
        var next_after: Int? = nil
    }
    /// 알림 하나의 내용. 보내는 것과 분리해 두어 화면 없이 확인할 수 있다.
    struct Announcement: Equatable {
        let identifier: String
        let title: String
        let body: String
        /// 눌렀을 때 열 탭을 정하는 알림 종류. 여러 개를 묶은 알림은 비어 있다.
        let kind: String
        /// 눌렀을 때 찾아가 짚어 줄 항목. 묶은 알림은 비어 있다.
        var target = ""
        /// 위시리스트 알림이면 그 카드. 마켓을 그 카드로 찾아 연다.
        var printing: String? = nil
    }

    /// 지금 계정의 알림 담당. 온라인 창이 「내가 방금 한 일」 을 알려 줄 때 쓴다.
    static weak var current: OnlineAlerts?

    /// 알림을 눌렀을 때 어느 탭을 열지 싣는 키.
    nonisolated static let kindKey = "ppb.online.kind"
    nonisolated static let targetKey = "ppb.online.target"
    nonisolated static let printingKey = "ppb.online.printing"
    /// 이보다 많이 한꺼번에 오면 하나로 묶는다. 오래 꺼 두었다 켰을 때 알림이 줄줄이 뜨지 않게 한다.
    static let separateLimit = 3

    private let defaults: UserDefaults
    private let seenKey: String
    private var checking = false
    private var lastUnread: Int?
    /// 다음 확인은 알리지 않고 넘긴다. 내가 방금 한 일(수락, 구매)로 생긴 알림을 나에게 다시
    /// 알리지 않으려는 것이다. 새 서버는 그런 알림을 처음부터 읽음으로 만들지만 예전 서버는 아니다.
    var quietNext = false

    init(storageKey: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seenKey = "ppb.online.alerts.lastSeen.\(storageKey)"
    }

    /// 마지막으로 확인한 알림 번호. 한 번도 확인하지 않았으면 nil.
    private(set) var lastSeen: Int? {
        get { defaults.object(forKey: seenKey) as? Int }
        set { defaults.set(newValue, forKey: seenKey) }
    }

    /// 알릴 것만 고른다. 이미 읽은 것과, 내가 직접 산 기록은 알릴 소식이 아니다.
    static func fresh(_ items: [Item]) -> [Item] {
        items.filter { !$0.read && $0.kind != "listing_bought" }
    }

    static func text(_ item: Item) -> String {
        OnlineText.notificationText(kind: item.kind, nickname: item.detail?.nickname,
                                    printing: item.detail?.printing, unitTokens: item.detail?.unit_tokens)
    }

    /// 새 알림들을 macOS 알림 내용으로. 몇 개까지는 하나씩, 많으면 가장 최근 것을 앞세워 하나로 묶는다.
    static func announcements(for fresh: [Item]) -> [Announcement] {
        guard fresh.count > separateLimit else {
            return fresh.map { item in
                let tab = OnlineText.destination(item.kind) ?? .alerts
                return Announcement(identifier: "ppb-online-\(item.id)", title: OnlineText.l.onlineTab(tab),
                                    body: text(item), kind: item.kind, target: item.target ?? "",
                                    printing: item.detail?.printing)
            }
        }
        guard let newest = fresh.max(by: { $0.id < $1.id }) else { return [] }
        return [Announcement(identifier: "ppb-online-\(newest.id)",
                             title: OnlineText.l.newAlertsCount(fresh.count),
                             body: OnlineText.l.andMoreAlerts(text(newest), fresh.count - 1), kind: "")]
    }

    /// 알림을 눌렀을 때 열 탭.
    static func destination(kind: String) -> OnlineHubModel.Tab {
        OnlineText.destination(kind) ?? .alerts
    }

    /// 알림 개수를 확인할 때마다 부른다. `fetch` 는 서버 경로를 받아 응답을 돌려준다.
    /// 새로 알린 내용을 돌려준다(알림을 꺼 두었거나 조용히 넘겼으면 비어 있다).
    @discardableResult
    func check(summary: RemoteGameSession.NotificationSummary, enabled: Bool,
               fetch: (String) async throws -> Data) async -> [Announcement] {
        guard !checking else { return [] }
        checking = true
        defer { checking = false }
        let quiet = quietNext
        quietNext = false
        let unreadBefore = lastUnread
        lastUnread = summary.unread
        do {
            guard let seen = lastSeen else {
                // 처음 켠 기기: 쌓여 있던 것은 지나간 일이다. 여기까지 본 것으로 치고 그 뒤부터 알린다.
                if let latest = summary.latest_id { lastSeen = latest }
                else { lastSeen = try await items(after: 0, pages: 50, fetch: fetch).map(\.id).max() ?? 0 }
                return []
            }
            if let latest = summary.latest_id {
                // 계정을 새로 만들었거나 서버 기록이 줄었으면 위치를 다시 맞춘다.
                if latest < seen { lastSeen = latest }
                guard latest > seen else { return [] }
            } else if let unreadBefore, summary.unread <= unreadBefore {
                // 최신 번호를 주지 않는 예전 서버: 안 읽은 수가 늘었을 때만 목록을 읽는다.
                return []
            }
            let arrived = try await items(after: seen, pages: 5, fetch: fetch)
            guard let newest = arrived.map(\.id).max() else { return [] }
            lastSeen = newest
            guard enabled, !quiet else { return [] }
            let announcements = Self.announcements(for: Self.fresh(arrived))
            Self.post(announcements)
            return announcements
        } catch {
            // 다음 확인 때 같은 자리에서 다시 읽는다. 알림 확인 실패로 동기화를 실패로 만들지 않는다.
            return []
        }
    }

    private func items(after: Int, pages: Int, fetch: (String) async throws -> Data) async throws -> [Item] {
        var cursor = after
        var all: [Item] = []
        for _ in 0..<pages {
            let page = try JSONDecoder().decode(Page.self, from: await fetch("v1/notifications?after=\(cursor)&limit=100"))
            all += page.items
            guard let next = page.next_after else { break }
            cursor = next
        }
        return all
    }

    static func post(_ announcements: [Announcement]) {
        // `UNUserNotificationCenter.current()` 는 번들이 등록되지 않았으면 예외로 앱을 죽인다.
        guard AppEnv.canUseNotifications else { return }
        for announcement in announcements {
            let content = UNMutableNotificationContent()
            content.title = announcement.title
            content.body = announcement.body
            content.sound = .default
            var info = [kindKey: announcement.kind, targetKey: announcement.target]
            if let printing = announcement.printing { info[printingKey] = printing }
            content.userInfo = info
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: announcement.identifier, content: content, trigger: nil))
        }
    }
}
