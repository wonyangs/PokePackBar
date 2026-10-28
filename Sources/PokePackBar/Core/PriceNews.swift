import Foundation
import UserNotifications

/// 하루 사이에 바뀐 값 하나. 서버의 `v1/prices/movers` 가 준다.
///
/// `kind` 가 `printing` 이면 `item` 은 판형 키(`카드#판형`), `card` 면 판형 시세가 없는 카드의
/// 대표값, `pack` 이면 세트 번호다.
struct PriceMove: Decodable, Equatable, Identifiable, Sendable {
    let kind: String
    let item: String
    let before: Double
    let after: Double
    /// 내 카드 목록에서만 온다. 그 시세로 값이 매겨지는 내 장수.
    var count: Int? = nil

    var id: String { "\(kind):\(item)" }
    var rose: Bool { after > before }
    var rate: Double { before > 0 ? (after - before) / before : 0 }
    /// 장수까지 곱한 값의 변화(달러).
    var valueChange: Double { (after - before) * Double(count ?? 1) }

    /// 카드 번호는 마지막 「#」 앞이다. 앱이 모르는 판형 이름이 와도 카드는 맞게 가린다.
    var cardID: String {
        guard kind == "printing", let mark = item.lastIndex(of: "#") else { return item }
        return String(item[..<mark])
    }

    var finish: CardFinish? {
        guard kind == "printing", let mark = item.lastIndex(of: "#") else { return nil }
        return CardFinish(rawValue: String(item[item.index(after: mark)...]))
    }
}

/// 가장 최근 기록일의 큰 변동과 내 카드의 변동.
struct PriceReport: Decodable, Equatable, Sendable {
    /// 기록이 아직 하루도 없으면 nil.
    let day: String?
    /// 비교한 앞 기록일. 첫 기록일이면 nil.
    let since: String?
    let changed: Int
    let risers: [PriceMove]
    let fallers: [PriceMove]
    let packs: [PriceMove]
    let owned: [PriceMove]

    /// 알릴 만큼 오른 내 카드. 몇십 원 오른 것까지 알리면 날마다 울린다.
    var notableOwnedRises: [PriceMove] {
        owned.filter { $0.rose && $0.rate >= 0.05 && $0.after - $0.before >= 0.5 }
    }
}

/// 한 판형, 카드, 팩의 기록. 값이 바뀐 날만 점이 있고, 그사이는 앞 값이 이어진다.
struct PriceSeries: Decodable, Equatable, Sendable {
    struct Point: Decodable, Equatable, Sendable {
        let day: String
        let usd: Double
    }
    let kind: String
    let item: String
    let latest_day: String?
    let points: [Point]
}

extension PriceSeries {
    struct Sample: Equatable, Identifiable, Sendable {
        let date: Date
        let usd: Double
        var id: Date { date }
    }

    /// 그릴 점. 마지막 값은 최근 기록일까지 이어 둔다. 그날 바뀌지 않았어도 그날의 값이다.
    func samples(calendar: Calendar = .current) -> [Sample] {
        var result = points.compactMap { point in
            PriceHistoryRequest.day(point.day, calendar: calendar).map { Sample(date: $0, usd: point.usd) }
        }
        if let last = result.last,
           let latest = latest_day.flatMap({ PriceHistoryRequest.day($0, calendar: calendar) }),
           latest > last.date {
            result.append(Sample(date: latest, usd: last.usd))
        }
        return result
    }

    /// 그 날짜의 값. 값이 바뀐 날만 점이 있으므로 그날이나 그 앞의 마지막 점이다.
    static func value(at date: Date, in samples: [Sample]) -> Sample? {
        samples.last { $0.date <= date } ?? samples.first
    }
}

enum PriceHistoryRange: Int, CaseIterable, Identifiable, Sendable {
    case month = 30, quarter = 90, all = 0
    var id: Int { rawValue }
}

/// 서버에 물을 경로. 어떤 기록을 볼지는 앱이 보여 주는 값과 같은 것으로 고른다.
enum PriceHistoryRequest {
    static let movers = "v1/prices/movers"

    static func path(kind: String, item: String, range: PriceHistoryRange) -> String {
        // 판형 키의 「#」 는 그대로 두면 주소의 조각으로 읽힌다.
        let encoded = item.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? item
        return "v1/prices/history?kind=\(kind)&item=\(encoded)&days=\(range.rawValue)"
    }

    /// 판형 시세가 따로 있으면 그 판형, 없으면 카드 대표값. 카드 상세의 값이 고르는 순서와 같다.
    static func card(_ cardID: String, finish: CardFinish?, prices: CardPrices?) -> (kind: String, item: String) {
        if let finish, prices?.exactPrice(cardID: cardID, finish: finish) != nil {
            return ("printing", CardPrintingKey(cardID: cardID, finish: finish).storageKey)
        }
        return ("card", cardID)
    }

    /// 기록일(`yyyy-MM-dd`)을 이 기기의 그날 자정으로. 날짜로만 보여 주므로 시간대가 달라도
    /// 같은 날로 읽혀야 한다. UTC 자정으로 두면 미국에서는 전날로 적힌다.
    static func day(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// 「오늘의 시세」. 시세가 새로 들어올 때 서버에서 한 번 읽어 두고, 통계 탭과 알림이 함께 쓴다.
///
/// 내 카드가 크게 오른 날은 macOS 알림을 한 번 보낸다. 어느 날까지 알렸는지는 계정마다 기기에
/// 적어 둔다. 처음 켠 기기는 그날을 기준으로만 잡고 알리지 않는다. 지난 소식은 소식이 아니다.
@MainActor @Observable
final class PriceNews {
    private(set) var report: PriceReport?
    private(set) var failed = false
    /// 서버가 아직 이 기능을 모른다. 다시 묻지 않는다.
    private(set) var unsupported = false
    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var loadedVersion: String?
    @ObservationIgnored private var loading = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let announcedKey: String

    /// 시세가 그대로여도 내 카드가 바뀌면 내 변동도 바뀐다. 그만큼만 다시 읽는다.
    static let staleAfter: TimeInterval = 30 * 60

    init(storageKey: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        announcedKey = "ppb.online.priceNews.announced.\(storageKey)"
    }

    /// 마지막으로 알림을 판단한 기록일.
    private(set) var announcedDay: String? {
        get { defaults.string(forKey: announcedKey) }
        set { defaults.set(newValue, forKey: announcedKey) }
    }

    /// 시세 버전이 바뀌었거나 읽은 지 오래됐으면 다시 읽는다. `maxAge` 로 더 자주 읽을 수 있다.
    func refresh(version: String?, maxAge: TimeInterval = PriceNews.staleAfter,
                 fetch: (String) async throws -> Data) async {
        guard !loading, !unsupported else { return }
        if version == loadedVersion, let loadedAt, Date().timeIntervalSince(loadedAt) < maxAge { return }
        loading = true
        defer { loading = false }
        do {
            let fresh = try JSONDecoder().decode(PriceReport.self, from: await fetch(PriceHistoryRequest.movers))
            if fresh != report { report = fresh }
            failed = false
            loadedAt = Date()
            loadedVersion = version
        } catch let failure as RemoteGameSession.Failure where failure.status == 404 {
            unsupported = true
        } catch {
            failed = report == nil
        }
    }

    /// 아직 판단하지 않은 기록일이면 알림 내용을 만든다. 알리지 않더라도 그날은 판단한 것으로 친다.
    func announcement(enabled: Bool, title: String, body: (PriceMove, Int) -> String) -> OnlineAlerts.Announcement? {
        guard let report, let day = report.day, day != announcedDay else { return nil }
        let first = announcedDay == nil
        announcedDay = day
        let rises = report.notableOwnedRises
        guard enabled, !first, let top = rises.first else { return nil }
        return OnlineAlerts.Announcement(identifier: "ppb-price-\(day)", title: title,
                                         body: body(top, rises.count - 1), kind: Self.alertKind)
    }

    /// 알림을 눌렀을 때 통계 탭을 열게 하는 종류.
    nonisolated static let alertKind = "price_movers"
}
