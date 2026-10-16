import AppKit
import SwiftUI

@MainActor
final class OnlineWindow: NSObject, NSWindowDelegate {
    static let shared = OnlineWindow()
    private var window: NSWindow?
    private var model: OnlineHubModel?

    /// `section` 이 있으면 그 탭으로 연다. 메뉴바의 교환 제안이나 알림 개수를 눌렀을 때 쓴다.
    /// `myListings` 는 마켓 탭을 「내 판매」 부터 연다. 판매 알림을 눌렀을 때 쓴다.
    func show(wallet: WalletStore, section: OnlineHubModel.Tab? = nil, myListings: Bool = false) {
        OnlineText.wallet = wallet
        if let window {
            if myListings { model?.opensMyListings = true }
            if let section, model?.section != section { model?.section = section }
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model?.visible = true; return
        }
        let model = OnlineHubModel(wallet: wallet)
        if myListings { model.opensMyListings = true }
        if let section { model.section = section }
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = OnlineText.l.onlineWindowTitle
        window.minSize = NSSize(width: 740, height: 540)
        window.contentView = NSHostingView(rootView: OnlineHubView(model: model))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        model.visible = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 알림을 눌렀을 때. 그 일을 처리할 탭을 열고 해당 교환, 판매 글, 친구 신청을 짚어 준다.
    func show(wallet: WalletStore, followingAlert kind: String, target: String, printing: String? = nil) {
        show(wallet: wallet)
        model?.follow(kind: kind, target: target, printing: printing)
    }

    /// 카드 상세의 「마켓에 팔기」. 마켓의 「팔기」를 그 카드로 연다.
    func showSelling(wallet: WalletStore, cardID: String) {
        show(wallet: wallet, section: .market)
        model?.opensMarketSell = cardID
    }

    /// 카드 상세의 마켓 줄. 마켓의 「사기」를 그 카드로 찾아 둔다.
    func showBuying(wallet: WalletStore, cardID: String) {
        show(wallet: wallet, section: .market)
        model?.openBuying(cardID: cardID)
    }

    func windowWillClose(_ notification: Notification) { model?.visible = false }
    func windowDidMiniaturize(_ notification: Notification) { model?.visible = false }
    func windowDidDeminiaturize(_ notification: Notification) { model?.visible = true }
}

@MainActor @Observable
final class OnlineHubModel {
    enum Phase { case idle, loading, ready, failed(String) }
    let wallet: WalletStore
    var visible = false
    var phase: Phase = .idle
    /// 마지막 실패 그대로. 배너가 종류와 요청 번호를 고를 때 쓴다.
    var failure: (any Error)?
    var data: [String: Any] = [:]
    var period = 0
    var mode = ""
    var setID = ""
    /// 탭. 서버 조회 분기와 레이아웃 감사가 이 값을 쓰고, 보이는 이름은 언어에 따라 바뀐다.
    enum Tab: String, CaseIterable, Sendable { case market, trades, social, stats, jobs, alerts }
    var section: Tab = .market
    var message: String?
    /// 교환이 성사된 순간. 창 가운데에 잠깐 띄운다.
    var celebration: OnlineCelebration?
    var documents: [String: [String: Any]] = [:]
    var generation = 0
    var offset = 0
    var search = ""
    var selectedFriend = ""
    var mutating = false
    var marketSet = ""
    var marketTier = ""
    var marketFinish = ""
    var marketSort = "newest"
    /// 판매자 거르기. 빈 값은 모두, "players" 는 트레이너가 올린 것, "bot" 은 봇 매물(로테이션)이다.
    var marketSeller = ""
    /// 내게 한 장도 없는 카드만 볼지. 서버가 거른다.
    var marketMissing = false
    var ownListings = false
    /// 마켓의 「보낸 제안」을 보고 있는지. 그때는 판매 글 대신 내가 보낸 가격 제안을 받는다.
    var sentOffers = false
    /// 마켓 탭이 열릴 때 「내 판매」 부터 보여 줄지. 판매 알림을 누르면 켠다.
    var opensMyListings = false
    /// 마켓 탭을 「사기」 로 돌려놓을지. 위시리스트 알림을 누르면 켠다.
    var opensMarketBuy = false
    /// 마켓 탭을 「보낸 제안」 으로 열지. 내 가격 제안이 수락, 거절되거나 닫혔다는 알림을 누르면 켠다.
    var opensSentOffers = false
    /// 마켓 탭을 「팔기」 로 열고 찾아 둘 카드. 카드 상세의 「마켓에 팔기」가 넣는다.
    var opensMarketSell: String?
    var tradeDraft: [String: Any]?
    /// 친구별 교환 바인더(그 친구가 내놓을 수 있는 카드). 교환 칸이 「나는 없고 친구는 남는 카드」를
    /// 바로 보여 주고, 카드를 고르는 창도 같은 것을 쓴다.
    var friendBinders: [String: FriendTradeBinder] = [:]
    @ObservationIgnored private var privateDataEpoch = 0
    /// 알림이 가리킨 항목(교환, 판매 글, 친구 관계)의 서버 번호. 그 탭이 이 항목을 화면 안으로
    /// 끌어오고 테두리로 잠깐 짚어 준다. 예전에는 탭만 열려서 어느 것인지 목록에서 다시 찾아야 했다.
    private(set) var focusID: String?
    @ObservationIgnored private var focusFound = false
    @ObservationIgnored private var focusToken = 0
    var openingJobs: [RemoteGameSession.OpeningJob] = []
    var stopOpening = false
    var openingProgress: String?
    private var refreshAgain = false
    private var refreshAgainFull = false
    /// 알림을 최신순으로 주지 못하는 예전 서버. 한 번 확인하면 그 뒤로는 예전 방식으로만 묻는다.
    private(set) var legacyAlerts = false
    init(wallet: WalletStore) { self.wallet = wallet }
    var remote: RemoteGameSession? { wallet.remote }
    /// 다시 불러오는 동안에도 마지막 실패 안내를 그대로 둔다. 15초마다 사라졌다 다시 뜨면
    /// 연결이 끊겼다 붙는 것처럼 보인다. 성공하면 `failure` 가 비워지며 사라진다.
    var errorText: String? {
        if case .failed(let text) = phase { return text }
        if case .loading = phase, let failure { return OnlineText.message(for: failure) }
        return nil
    }
    var loading: Bool { if case .loading = phase { return true }; return false }
    var canWrite: Bool {
        guard case .ready = phase else { return false }
        return remote?.ready == true && !wallet.resourceActionsDisabled && !mutating
    }

    enum Connection { case connected, checking, unreachable, serverProblem, signedOut }

    /// 머리글의 연결 표시. 탭 데이터를 불러오는 중이거나 한 요청이 서버 오류로 실패했다고
    /// 연결이 끊긴 것은 아니다. 로그인 세션과 서버에 닿았는지만 본다.
    var connection: Connection {
        guard let remote, !remote.authenticationExpired else { return .signedOut }
        if failure is ServerUnreachable || remote.lastFailure is ServerUnreachable { return .unreachable }
        if remote.ready { return .connected }
        return remote.lastFailure == nil ? .checking : .serverProblem
    }

    /// `full` 이 아니면 지금 탭에 필요한 것만 받는다. 계정 동기화는 앱이 10초마다 따로 하므로
    /// 탭을 옮기거나 거를 때마다 다시 할 필요가 없다. 창을 열 때, 주기 갱신, 새로고침, 거래 뒤에만
    /// 동기화와 서버 상태, 프로필까지 함께 받는다.
    /// `force` 는 사용자가 누른 다시 시도와 새로고침이다. 끊긴 동안 자동 갱신은 재연결 간격을 지킨다.
    func refresh(full: Bool = true, force: Bool = false) async {
        guard !loading, !mutating else {
            refreshAgain = true
            refreshAgainFull = refreshAgainFull || full
            return
        }
        guard let remote else {
            failure = OnlineSignedOut()
            phase = .failed(OnlineText.l.localModeNotice)
            return
        }
        phase = .loading
        do {
            if full || !remote.ready { await remote.synchronize(force: force) }
            guard remote.ready else {
                throw remote.lastFailure ?? RemoteGameSession.Failure(message: remote.error ?? ServerAuthentication.loginRequired)
            }
            if full || documents["server"] == nil { documents["server"] = try await read("v1/server/status") }
            let currentSection = section
            if currentSection == .jobs {
                struct Jobs: Decodable { let items: [RemoteGameSession.OpeningJob] }
                openingJobs = try JSONDecoder().decode(Jobs.self, from: await remote.api("v1/opening-jobs?offset=\(offset)")).items
            }
            if currentSection == .stats {
                var query = "v1/stats?days=\(period)"
                if !mode.isEmpty { query += "&mode=\(mode)" }
                if !setID.isEmpty { query += "&set_id=\(setID)" }
                data = try await read(query)
            } else {
                if full || documents["profile"] == nil { documents["profile"] = try await read("v1/profile") }
                if currentSection == .social {
                    documents["friends"] = try await read("v1/friends?offset=\(offset)")
                    documents["inventory"] = try await read("v1/inventory?q=\(escaped(search))&offset=\(offset)")
                    documents["blocks"] = try await read("v1/blocks?offset=\(offset)")
                    documents["matches"] = try await read("v1/matches?offset=\(offset)")
                    if !selectedFriend.isEmpty {
                        do { documents["friend"] = try await read("v1/friends/\(selectedFriend)") }
                        catch let error as RemoteGameSession.Failure {
                            if [403, 404].contains(error.status ?? 0) {
                                selectedFriend = ""; documents["friend"] = nil; documents["friendInventory"] = nil
                            } else { throw error }
                        }
                    }
                } else if currentSection == .alerts {
                    documents["notifications"] = try await readNotifications()
                } else if currentSection == .trades {
                    documents["trades"] = try await read("v1/trades?offset=\(offset)")
                    documents["friends"] = try await read("v1/friends?limit=100")
                    documents["matches"] = try await read("v1/matches?limit=100")
                } else if currentSection == .market, sentOffers {
                    documents["offersSent"] = try await readOffers("v1/market/offers?role=sent&offset=\(offset)")
                } else if currentSection == .market {
                    // 내 판매를 볼 때는 판매 글마다 받은 가격 제안도 함께 받는다.
                    if ownListings { documents["offersReceived"] = try await readOffers("v1/market/offers?role=received&limit=100") }
                    documents["listings"] = try await read("v1/market/listings?q=\(escaped(search))&set_id=\(escaped(marketSet))&tier=\(escaped(marketTier))&finish=\(escaped(marketFinish))&sort=\(marketSort)&seller=\(marketSeller)&missing=\(marketMissing)&mine=\(ownListings)&offset=\(offset)")
                }
            }
            generation += 1
            phase = .ready
            failure = nil
        } catch {
            if remote.authenticationExpired { clearPrivateData() }
            fail(error, while: "load \(section.rawValue)")
        }
        if refreshAgain {
            let again = refreshAgainFull
            refreshAgain = false
            refreshAgainFull = false
            await refresh(full: again)
        }
    }

    /// 알림은 최신 것부터 받는다. 쌓인 알림이 많으면 방금 온 것이 맨 뒤 쪽에 있어, 예전에는
    /// 「더 보기」를 끝까지 눌러야 보였다. `offset` 은 다음 쪽의 기준 번호다.
    /// 최신순을 모르는 예전 서버는 응답에 순서를 적지 않으므로, 그때는 오래된 순 그대로 둔다.
    private func readNotifications() async throws -> [String: Any] {
        if !legacyAlerts {
            let page = try await read(offset > 0 ? "v1/notifications?newest=true&before=\(offset)"
                                                 : "v1/notifications?newest=true")
            if page["order"] != nil { return page }
            legacyAlerts = true
            if offset == 0 { return page }
        }
        return try await read("v1/notifications?after=\(offset)")
    }

    /// 다음 쪽의 기준 번호. 없으면 끝이다.
    var nextNotificationCursor: Int? {
        let page = documents["notifications"]
        return (legacyAlerts ? page?["next_after"] : page?["next_before"]) as? Int
    }

    static func shownNotificationBoundary(_ items: [[String: Any]]) -> Int? {
        items.map { $0.int("id") }.filter { $0 > 0 }.max()
    }

    /// 안 읽은 알림을 한 번에 읽음으로 바꾼다.
    ///
    /// 서버가 한 번에 처리하면 그 명령 하나를 보낸다. 마지막으로 확인한 알림까지만 바꾸므로 누르는
    /// 사이에 새로 온 것은 안 읽음으로 남는다. 그 명령이 없는 예전 서버에서는 지금 보이는 것만
    /// 하나씩 바꾼다.
    func markAllNotificationsRead() async {
        guard canWrite, let remote else { return }
        let unread = remote.notificationSummary?.unread ?? 0
        if remote.notificationSummary?.latest_id != nil {
            // The summary can advance while this page remains on screen.
            // Preserve notifications that arrived after the displayed page.
            guard let latest = Self.shownNotificationBoundary(items("notifications")) else { return }
            var values: [String: Any] = ["action": "notification_read_all"]
            values["notification_id"] = latest
            if await mutate("notifications", values, quiet: true), unread > 0 {
                message = OnlineText.l.alertsMarkedRead(unread)
            }
            return
        }
        mutating = true
        var marked = 0
        for item in items("notifications") where !item.bool("read") {
            let body: [String: Any] = ["action": "notification_read", "notification_id": item.int("id"),
                                       "request_id": UUID().uuidString, "expected_revision": remote.revision]
            do {
                _ = try await remote.onlineMutation(
                    path: "v1/notifications", body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
                marked += 1
            } catch {
                mutating = false
                fail(error, while: "notifications")
                return
            }
        }
        mutating = false
        guard marked > 0 else { return }
        message = OnlineText.l.alertsMarkedRead(marked)
        await refresh()
        await remote.refreshNotificationSummary()
    }

    /// 마켓의 「사기」를 그 카드 이름과 출처 팩으로 찾아 둔다. 위시리스트 알림을 누를 때와 같은 방식이고,
    /// 같은 이름의 다른 세트 카드가 섞이지 않게 세트도 고른다. 다른 조건은 푼다.
    func openBuying(cardID: String) {
        opensMarketBuy = true
        marketTier = ""; marketFinish = ""; marketSeller = ""; marketMissing = false
        marketSet = CardIndex.shared?.card(cardID)?.setID ?? ""
        if let name = OnlineText.searchName(cardID) { search = name }
    }

    // MARK: 알림이 가리키는 곳

    /// 알림이 가리키는 곳으로 간다. 탭을 열고, 그 일을 찾아 짚어 준다.
    func follow(kind: String, target: String, printing: String? = nil) {
        let destination = OnlineText.destination(kind) ?? .alerts
        switch kind {
        case "listing_sold", "listing_expired", "offer_received":
            // 팔렸거나 기한이 지난 내 판매, 내 판매에 온 가격 제안은 「내 판매」 에서 확인한다.
            // 사기 화면부터 열면 다시 찾아가야 한다.
            opensMyListings = true
        case "offer_accepted", "offer_rejected", "offer_expired":
            opensSentOffers = true
        case "wishlist_listing":
            // 그 카드의 판매 글만 남게 이름으로 찾아 둔다. 걸어 둔 조건에 가려 안 보이면 안 되니 조건은 푼다.
            opensMarketBuy = true
            if let name = printing.flatMap(OnlineText.searchName) {
                search = name
                marketSet = ""; marketTier = ""; marketFinish = ""; marketSeller = ""; marketMissing = false
            }
        default:
            break
        }
        // 여러 개를 묶은 알림은 가리키는 항목이 없다. 앞서 짚던 것도 거둔다.
        focus(on: destination == .alerts ? "" : target)
        // 탭이 바뀌면 화면이 알아서 새로 받는다. 이미 그 탭이면 방금 생긴 항목이 아직 없을 수 있어 직접 받는다.
        if section != destination { section = destination } else { Task { await refresh(full: false) } }
    }

    func focus(on id: String) {
        focusID = id.isEmpty ? nil : id
        focusFound = false
        expireFocus(after: 10)
    }

    /// 목록에 그 항목이 있으면 한 번만 그 번호를 돌려준다. 화면은 그쪽으로 스크롤한다.
    /// 15초마다 새로 받을 때마다 다시 끌려가지 않게 한 번으로 끝낸다.
    func takeFocus(among ids: [String]) -> String? {
        guard let focusID, !focusFound, ids.contains(focusID) else { return nil }
        focusFound = true
        expireFocus(after: 3)
        return focusID
    }

    /// 짚어 준 테두리는 잠깐 뒤에 거둔다. 그 항목이 목록에 없으면(이미 닫혔거나 다음 쪽) 조용히 잊는다.
    private func expireFocus(after seconds: Double) {
        focusToken += 1
        let token = focusToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, self.focusToken == token else { return }
            self.focusID = nil
        }
    }

    /// 친구의 교환 바인더를 새로 받는다. 이미 보여 주던 목록이 있으면 받는 동안 그대로 두고,
    /// 잠깐 끊겨 실패했다고 비우지 않는다.
    func loadFriendBinder(_ friendID: String,
                          fetch: (@MainActor () async -> FriendTradeBinder)? = nil) async {
        guard !friendID.isEmpty else { return }
        let epoch = privateDataEpoch
        if friendBinders[friendID] == nil { friendBinders[friendID] = .loading }
        let loaded: FriendTradeBinder
        if let fetch { loaded = await fetch() }
        else { loaded = await FriendTradeBinder.load(self, friendID: friendID) }
        guard epoch == privateDataEpoch else { return }
        if case .failed = loaded, case .ready? = friendBinders[friendID] { return }
        friendBinders[friendID] = loaded
    }

    func clearPrivateData() {
        privateDataEpoch += 1
        data = [:]; documents = [:]; selectedFriend = ""; tradeDraft = nil; message = nil
        friendBinders = [:]
        openingJobs = []; openingProgress = nil; stopOpening = true
    }

    func read(_ path: String) async throws -> [String: Any] {
        guard let remote else { throw RemoteGameSession.Failure(message: OnlineText.l.onlineLoginRequired) }
        return try JSONSerialization.jsonObject(with: await remote.api(path)) as? [String: Any] ?? [:]
    }
    /// 가격 제안 목록. 제안을 모르는 서버는 404 를 주므로 빈 목록으로 본다. 그렇지 않으면
    /// 내 판매 화면 전체가 실패로 바뀐다.
    private func readOffers(_ path: String) async throws -> [String: Any] {
        do { return try await read(path) }
        catch let error as RemoteGameSession.Failure where error.status == 404 { return ["items": []] }
    }
    func escaped(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    func items(_ key: String) -> [[String: Any]] { documents[key]?["items"] as? [[String: Any]] ?? [] }
    var profile: [String: Any] { documents["profile"]?["profile"] as? [String: Any] ?? [:] }

    /// 성공하면 true. 화면은 성공했을 때만 입력(교환 바구니 등)을 비운다.
    @discardableResult
    /// `quiet` 는 「완료」 줄을 띄우지 않는다. 알림을 눌러 다른 탭으로 옮겨 가며 읽음으로 바꿀 때
    /// 옮겨 간 탭에 뜬금없는 완료 표시가 남지 않게 한다.
    func mutate(_ route: String, _ values: [String: Any], quiet: Bool = false) async -> Bool {
        guard canWrite, let remote else { return false }
        mutating = true
        // 축하에 쓸 카드는 새로 고치기 전에 읽어 둔다. 성사되면 목록에서 상태가 바뀌거나 빠진다.
        let action = values["action"] as? String
        let accepted = action == "trade_accept"
            ? items("trades").first { $0.string("id") == values["target_id"] as? String } : nil
        let boughtListing = action == "listing_buy"
            ? items("listings").first { $0.string("id") == values["target_id"] as? String } : nil
        do {
            let body = values.merging(["request_id": UUID().uuidString, "expected_revision": remote.revision]) { _, right in right }
            _ = try await remote.onlineMutation(path: "v1/\(route)", body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
            if !quiet { message = OnlineText.l.actionDone }
            if let accepted {
                // 받은 제안을 수락했다: 나는 요청받은 카드를 주고 제안된 카드를 받는다.
                func first(_ key: String) -> String? { (accepted[key] as? [String: Int])?.keys.sorted().first }
                celebration = OnlineCelebration(kind: .trade(gave: first("requested"), got: first("offered")))
                SoundEffects.play(.chime(3))
            } else if let boughtListing {
                celebration = OnlineCelebration(kind: .bought(printing: boughtListing.string("printing"),
                                                              quantity: values["quantity"] as? Int ?? 1))
                SoundEffects.play(.pop)
            } else if action == "listing_create", let printing = values["printing"] as? String {
                celebration = OnlineCelebration(kind: .listed(printing: printing))
                SoundEffects.play(.pop)
            }
            mutating = false
            // 내가 방금 한 일로 생긴 알림은 macOS 알림으로 다시 알리지 않는다.
            OnlineAlerts.current?.quietNext = true
            await refresh()
            // 수락, 거절, 읽음 처리 뒤 메뉴바 개수가 다음 확인 때까지 남아 있지 않게 바로 갱신한다.
            await remote.refreshNotificationSummary()
            return true
        } catch {
            mutating = false
            fail(error, while: route)
            return false
        }
    }

    /// 서버 요청 실패는 전송 단계에서 이미 로그에 남는다. 응답은 받았지만 읽지 못한 경우
    /// (형식이 바뀐 응답 등)는 여기서만 보이므로 따로 남긴다.
    private func fail(_ error: any Error, while action: String) {
        let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
        if !(error is any ServerTraceable), !cancelled {
            AppLog.write("[online] \(action) failed: \(String(describing: error).prefix(400))")
        }
        failure = error
        phase = .failed(OnlineText.message(for: error))
    }

    func resumeOpening(_ initial: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true; stopOpening = false
        var job = initial
        do {
            while job.status == "active", visible, !stopOpening, !Task.isCancelled {
                openingProgress = OnlineText.l.jobProgress(total: job.total, completed: job.completed)
                job = try await remote.advanceOpeningJob(job).job
            }
            message = OnlineText.l.jobFinished(total: job.total, completed: job.completed)
        } catch { message = OnlineText.message(for: error) }
        mutating = false; openingProgress = nil
        if visible { await refresh() }
    }

    func cancelOpening(_ job: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true
        do { _ = try await remote.advanceOpeningJob(job, cancel: true); message = OnlineText.l.jobCancelled }
        catch { message = OnlineText.message(for: error) }
        mutating = false
        await refresh()
    }
}

@MainActor
struct OnlineHubView: View {
    @Bindable var model: OnlineHubModel


    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let error = model.errorText {
                OnlineFailureBanner(problem: OnlineProblem(model.failure), message: error,
                                    loading: model.loading, retryAt: model.remote?.retryAt,
                                    signIn: { AccountWindow.shared.show(wallet: model.wallet) }) { reload(full: true, force: true) }
            }
            if let jobs = model.documents["server"]?["jobs"] as? [[String: Any]],
               jobs.contains(where: { ["failed", "stale"].contains($0["state"] as? String ?? "") }) {
                Label(OnlineText.l.serverJobsProblem, systemImage: "exclamationmark.triangle")
                    .font(Typography.label).foregroundStyle(.orange)
            }
            Picker("", selection: $model.section) {
                // 답할 것이 있는 탭은 이름 옆에 개수를 붙인다. 예전에는 탭을 눌러 봐야 알았다.
                ForEach(OnlineHubModel.Tab.allCases, id: \.self) {
                    Text(OnlineText.tabTitle($0, summary: model.remote?.notificationSummary)).tag($0)
                }
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: model.section) { model.offset = 0; model.message = nil; reload() }
            if let message = model.message {
                Label(message, systemImage: "checkmark.circle").font(Typography.label).foregroundStyle(.secondary)
            }
            ZStack(alignment: .topLeading) {
                Group {
                    if model.remote?.authenticationExpired == true {
                        VStack(spacing: 12) {
                            OnlineEmptyState(icon: "lock", title: OnlineText.l.signInAgain,
                                             message: OnlineText.l.sessionExpiredMessage)
                            Button(OnlineText.l.signIn) { AccountWindow.shared.show(wallet: model.wallet) }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    else if model.section == .stats { statistics }
                    else if model.section == .social { OnlineSocialView(model: model) }
                    else if model.section == .trades { OnlineTradingView(model: model) }
                    else if model.section == .market { OnlineMarketView(model: model) }
                    else if model.section == .jobs { openingWork }
                    else { notifications }
                }
                // 섹션을 바꾸면 새 내용만 짧게 떠오른다. 이전 내용은 바로 빠진다 —
                // 둘이 겹쳐 흐려지면 글자가 겹쳐 보인다.
                .id(model.section)
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeOut(duration: 0.16), value: model.section)
        }
        .padding(22)
        .overlay {
            if let celebration = model.celebration {
                OnlineCelebrationView(celebration: celebration)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.6))
                        guard model.celebration?.id == celebration.id else { return }
                        withAnimation(.snappy(duration: 0.3)) { model.celebration = nil }
                    }
            }
        }
        .animation(.snappy(duration: 0.3), value: model.celebration)
        .onChange(of: model.remote?.authenticationExpired) {
            if model.remote?.authenticationExpired == true { model.clearPrivateData() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: model.visible) {
            guard model.visible else { return }
            while !Task.isCancelled && model.visible {
                await model.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    // MARK: 머리글

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(OnlineText.l.online).font(Typography.display)
                HStack(spacing: 6) {
                    Circle().fill(connectionStatus.color).frame(width: 7, height: 7)
                    Text(connectionStatus.text)
                    if let status = model.remote?.priceStatus, let last = status.last_success {
                        Text(OnlineText.l.priceAsOf(Date(timeIntervalSince1970: Double(last)).formatted(date: .abbreviated, time: .omitted)))
                            .padding(.leading, 6)
                    }
                }
                .font(Typography.label).foregroundStyle(.secondary)
            }
            Spacer()
            Text(OnlineText.l.availableFunds(OnlineText.won(tokens: model.wallet.availableTokens)))
                .font(Typography.bodySemibold).monospacedDigit()
            if model.loading { ProgressView().controlSize(.small) }
            Button { reload(full: true, force: true) } label: { Image(systemName: "arrow.clockwise") }
                .help(OnlineText.l.refresh).disabled(model.loading)
            Button { AccountWindow.shared.show(wallet: model.wallet) } label: { Image(systemName: "person.crop.circle") }
                .help(OnlineText.l.accountAndServer)
        }
    }

    private var connectionStatus: (text: String, color: Color) {
        switch model.connection {
        case .connected:
            let nickname = model.profile.string("nickname")
            return (nickname.isEmpty ? OnlineText.l.connectedStatus : nickname, .green)
        case .checking: return (OnlineText.l.checkingConnection, .secondary)
        case .unreachable: return (OnlineText.l.notConnected, .orange)
        case .serverProblem: return (OnlineText.l.serverErrorStatus, .orange)
        case .signedOut: return (OnlineText.l.signInNeeded, .secondary)
        }
    }

    // MARK: 알림

    /// 알림 한 줄. 누르면 그 일을 처리할 탭으로 옮겨 가고 읽음으로 바꾼다.
    @ViewBuilder
    private func notificationRow(_ item: [String: Any]) -> some View {
        let kind = item.string("kind")
        let info = OnlineText.notification(kind)
        let unread = !item.bool("read")
        let destination = OnlineText.destination(kind)
        let when = OnlineText.timeAgo(item.int("created_at"))
        let row = HStack(spacing: 12) {
            Image(systemName: info.icon).font(.system(size: 17))
                .foregroundStyle(unread ? Color.accentColor : Color.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                // 누가, 어떤 카드인지까지 말한다. 「교환 제안이 왔어요」 만으로는 열어 봐야 안다.
                Text(OnlineText.notificationText(item)).font(unread ? Typography.bodySemibold : Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
                if !when.isEmpty {
                    Text(when).font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if unread {
                Button(OnlineText.l.markRead) {
                    Task { await model.mutate("notifications", ["action": "notification_read", "notification_id": item.int("id")]) }
                }
                .disabled(!model.canWrite)
            }
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(unread ? Color.accentColor.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: unread)
        if destination != nil {
            row
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .hoverHighlight(cornerRadius: 8)
                .onTapGesture { open(item) }
                .help(OnlineText.l.openNotification)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: OnlineText.l.openNotification) { open(item) }
        } else {
            row
        }
    }

    private func open(_ item: [String: Any]) {
        if !item.bool("read"), model.canWrite {
            Task {
                await model.mutate("notifications", ["action": "notification_read", "notification_id": item.int("id")],
                                   quiet: true)
            }
        }
        model.follow(kind: item.string("kind"), target: item.string("target"),
                     printing: (item["detail"] as? [String: Any])?["printing"] as? String)
    }

    private var notifications: some View {
        let items = model.items("notifications")
        let unread = model.remote?.notificationSummary?.unread ?? items.filter { !$0.bool("read") }.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    OnlineEmptyState(icon: "bell", title: OnlineText.l.noNewAlerts,
                                     message: OnlineText.l.alertsEmptyHint)
                } else {
                    // 알림이 여러 개 쌓였을 때 하나씩 「확인」 을 누르지 않아도 되게 한다.
                    HStack(spacing: 10) {
                        Text(unread > 0 ? OnlineText.l.unreadAlerts(unread) : OnlineText.l.allAlertsRead)
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Button(OnlineText.l.markAllRead) { Task { await model.markAllNotificationsRead() } }
                            .disabled(unread == 0 || !model.canWrite)
                    }
                    .padding(.horizontal, 10)
                }
                ForEach(items, id: \.onlineID) { item in
                    notificationRow(item)
                }
                HStack {
                    if model.offset > 0 { Button(OnlineText.l.backToStart) { model.offset = 0; reload() } }
                    if let next = model.nextNotificationCursor {
                        Button(OnlineText.l.showMore) { model.offset = next; reload() }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            // 새 알림은 위에서 밀려 들어온다. 15초마다 새로 고칠 때 줄이 툭 끼어들지 않게 한다.
            .animation(.snappy(duration: 0.3), value: items.map(\.onlineID))
        }
    }

    // MARK: 대량 개봉

    private var openingWork: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(OnlineText.l.bulkOpeningIntro)
                    .font(Typography.label).foregroundStyle(.secondary)
                if let progress = model.openingProgress {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(progress).monospacedDigit()
                        Spacer()
                        Button(OnlineText.l.stopAfterBatch) { model.stopOpening = true }
                            .disabled(model.stopOpening)
                    }
                }
                if model.openingJobs.isEmpty {
                    OnlineEmptyState(icon: "shippingbox", title: OnlineText.l.noJobs,
                                     message: OnlineText.l.noJobsHint)
                }
                ForEach(model.openingJobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(CardIndex.shared?.set(job.set_id)?.name ?? job.set_id).font(Typography.bodySemibold)
                            OnlineBadge(text: job.status == "completed" ? OnlineText.l.jobCompleted : job.status == "cancelled" ? OnlineText.l.jobStopped : OnlineText.l.jobResumable,
                                        color: job.status == "active" ? .accentColor : .secondary)
                            Spacer()
                            Text(job.opening_mode == "game" ? OnlineText.l.gameMode : OnlineText.l.physicalMode)
                                .font(Typography.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(job.completed), total: Double(job.total))
                        Text(OnlineText.l.jobProgress(total: job.total, completed: job.completed))
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                        if job.status == "active" {
                            HStack {
                                Spacer()
                                Button(OnlineText.l.stopRemainingPacks, role: .destructive) { Task { await model.cancelOpening(job) } }
                                Button(OnlineText.l.resumeOpening) { Task { await model.resumeOpening(job) } }
                                    .buttonStyle(.borderedProminent)
                            }
                            .disabled(!model.canWrite)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                if model.offset > 0 || model.openingJobs.count >= 25 {
                    HStack {
                        Button(OnlineText.l.previousPage) { model.offset = max(0, model.offset - 25); reload() }.disabled(model.offset == 0 || model.mutating)
                        Button(OnlineText.l.nextPage) { model.offset += 25; reload() }.disabled(model.openingJobs.count < 25 || model.mutating)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 통계

    private var statistics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 메뉴바의 「통계」 탭(이 계정 전체 요약)과 이름이 같아 무엇이 다른지 헷갈렸다.
                Text(OnlineText.l.statsIntro)
                    .font(Typography.label).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    // 고정 폭을 주면 세그먼트가 그 안 가운데로 가서 다른 줄과 왼쪽 선이 어긋났다.
                    Picker(OnlineText.l.periodLabel, selection: $model.period) { Text(OnlineText.l.allTime).tag(0); Text(OnlineText.l.last7Days).tag(7); Text(OnlineText.l.last30Days).tag(30) }
                        .pickerStyle(.segmented).fixedSize()
                    Picker(OnlineText.l.modeLabel, selection: $model.mode) { Text(OnlineText.l.allModes).tag(""); Text(OnlineText.l.gameMode).tag("game"); Text(OnlineText.l.physicalMode).tag("realistic") }
                        .fixedSize()
                    Picker(OnlineText.l.setLabel, selection: $model.setID) {
                        Text(OnlineText.l.allSetsOption).tag("")
                        ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .fixedSize()
                }
                .labelsHidden()
                .onChange(of: model.period) { reload() }.onChange(of: model.mode) { reload() }.onChange(of: model.setID) { reload() }

                if let totals = model.data["totals"] as? [String: Any], !totals.isEmpty {
                    let number = { (key: String) in (totals[key] as? NSNumber)?.intValue ?? 0 }
                    // 여섯 칸을 3칸씩 두 줄로. 폭에 맞춰 늘리면 넓은 창에서 5칸과 1칸으로 갈라졌다.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        statTile(OnlineText.l.statOpened, OnlineText.l.packsCount(number("opened")))
                        statTile(OnlineText.l.statPurchased, OnlineText.l.packsCount(number("purchased")))
                        statTile(OnlineText.l.statNew, OnlineText.l.cardsCount(number("new")))
                        statTile(OnlineText.l.statDuplicates, OnlineText.l.cardsCount(number("duplicates")))
                        statTile(OnlineText.l.statSpent, OnlineText.won(tokens: number("purchase_spent")))
                        statTile(OnlineText.l.statIncome, OnlineText.won(tokens: number("sale_income")))
                    }
                    if let value = model.data["collection_usd"] as? Double, let prices = CardPrices.shared {
                        Text(OnlineText.l.collectionWorth(prices.formattedWithKRW(value, language: OnlineText.language)))
                            .font(Typography.body)
                    }
                    if let rate = model.data["new_rate"] as? Double {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(OnlineText.l.newCardRate(Int((rate * 100).rounded()))).font(Typography.labelSemibold)
                            ProgressView(value: rate).tint(.accentColor)
                        }
                    }
                    HStack(alignment: .top, spacing: 28) {
                        breakdown(OnlineText.l.cardsByTier, model.data["tiers"] as? [String: Int] ?? [:]) { raw in
                            CardTier(rawValue: raw).map { "\($0.rawValue) \(OnlineText.l.tierName($0))" } ?? raw
                        } order: { raw in -(CardTier(rawValue: raw)?.rank ?? 0) }
                        breakdown(OnlineText.l.cardsByFinish, model.data["finishes"] as? [String: Int] ?? [:]) { raw in
                            OnlineText.finish(raw)
                        } order: { _ in 0 }
                        breakdown(OnlineText.l.packKinds, model.data["variants"] as? [String: Int] ?? [:], packs: true) { raw in
                            switch raw {
                            case "standard", "celebrations": return OnlineText.l.regularPack
                            case "god": return OnlineText.l.godPackName
                            case "demigod": return OnlineText.l.demigodPackName
                            default:
                                guard let variant = PackVariant(rawValue: raw) else { return raw }
                                let badge = OnlineText.l.specialPackBadge(variant)
                                return badge.isEmpty ? OnlineText.l.regularPack : badge
                            }
                        } order: { raw in raw == "standard" ? 0 : 1 }
                    }
                    Text(OnlineText.l.statsDisclaimer + ((model.data["coverage_since"] as? String).map { " " + OnlineText.l.recordedSince($0) } ?? ""))
                        .font(Typography.caption).foregroundStyle(.secondary)
                } else {
                    OnlineEmptyState(icon: "chart.bar", title: OnlineText.l.noRecordsYet,
                                     message: OnlineText.l.noRecordsHint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typography.label).foregroundStyle(.secondary)
            Text(value).font(Typography.heading).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func breakdown(_ title: String, _ counts: [String: Int], packs: Bool = false,
                           label: @escaping (String) -> String, order: (String) -> Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typography.labelSemibold)
            let keys = counts.keys.sorted { (order($0), -(counts[$0] ?? 0), $0) < (order($1), -(counts[$1] ?? 0), $1) }
            if keys.isEmpty { Text(OnlineText.l.noneLabel).font(Typography.label).foregroundStyle(.secondary) }
            ForEach(keys, id: \.self) { key in
                HStack {
                    Text(label(key)).font(Typography.label)
                    Spacer(minLength: 12)
                    Text(packs ? OnlineText.l.packsCount(counts[key] ?? 0) : OnlineText.l.cardsCount(counts[key] ?? 0)).font(Typography.label).monospacedDigit()
                }
            }
        }
        .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
    }

    /// 탭 이동, 필터, 쪽 넘기기는 그 탭만. 새로고침 버튼과 다시 시도는 전체.
    private func reload(full: Bool = false, force: Bool = false) { Task { await model.refresh(full: full, force: force) } }
}

extension Dictionary where Key == String, Value == Any {
    var onlineID: String { string("id") + ":" + string("printing") + ":" + string("public_id") }
    func string(_ key: String) -> String { self[key] as? String ?? (self[key] as? NSNumber)?.stringValue ?? "" }
    func int(_ key: String) -> Int { (self[key] as? NSNumber)?.intValue ?? 0 }
    func bool(_ key: String) -> Bool { self[key] as? Bool ?? false }
}
