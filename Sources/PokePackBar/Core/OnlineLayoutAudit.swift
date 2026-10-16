import AppKit
import SwiftUI

/// Native production views, temporary fixtures only. Does not log in or poll.
@MainActor enum OnlineLayoutAudit {
    static func run(output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: output.appendingPathComponent("fixture.json"))
        wallet.setLanguage(LayoutAuditOptions.language)
        LayoutAuditOptions.applyAppearance()
        OnlineText.wallet = wallet
        let model = OnlineHubModel(wallet: wallet)
        let card = CardIndex.shared?.cards.first?.id ?? "base1-1"
        let profile: [String: Any] = ["nickname": "레이아웃 검사", "friend_code": "0123456789ABCDEF", "wishlist": [], "binder": []]
        let row: [String: Any] = ["id": UUID().uuidString, "printing": "\(card)#holo", "nickname": "교환 친구", "public_id": UUID().uuidString,
            "status": "pending", "incoming": true, "offered": ["\(card)#holo": 1], "requested": ["sv8pt5-1#normal": 2], "expires_at": Int(Date().timeIntervalSince1970) + 3600,
            "quantity": 4, "unit_tokens": 1200, "version": 0]
        // 알림은 최신순, 상대 이름과 카드가 붙은 것과 예전 서버처럼 붙지 않은 것을 함께 둔다.
        let now = Int(Date().timeIntervalSince1970)
        let notes: [[String: Any]] = [
            ["id": 4, "kind": "trade_request", "target": "t", "read": false, "created_at": now - 300,
             "detail": ["nickname": "교환 친구"]],
            ["id": 3, "kind": "listing_sold", "target": "l", "read": false, "created_at": now - 3 * 3600,
             "detail": ["printing": "\(card)#holo", "unit_tokens": 1_280_000]],
            ["id": 2, "kind": "friend_accept", "target": "f", "read": true, "created_at": now - 2 * 86_400,
             "detail": ["nickname": "새 친구"]],
            ["id": 1, "kind": "trade_expired", "target": "t", "read": true, "created_at": now - 9 * 86_400],
        ]
        // 친구 줄: 받은 신청, 친구, 보낸 신청. 친구 줄에는 교환 제안과 바인더 보기가 함께 놓인다.
        func friend(_ name: String, _ status: String, incoming: Bool) -> [String: Any] {
            ["id": UUID().uuidString, "version": 0, "status": status, "incoming": incoming, "public_id": UUID().uuidString,
             "nickname": name, "level": 12, "expires_at": now + 86_400]
        }
        let friends = [friend("새 친구", "pending", incoming: true), friend("교환 친구", "accepted", incoming: false),
                       friend("기다리는 친구", "pending", incoming: false)]
        // 마켓: 사람이 올린 글 하나와 서버가 올린 로테이션 카드 둘(아직 안 산 것, 이미 한 장 산 것).
        func rotation(_ printing: String, bought: Bool) -> [String: Any] {
            ["id": UUID().uuidString, "printing": printing, "nickname": "", "public_id": "", "status": "active",
             "quantity": bought ? 3 : 5, "unit_tokens": 2_400_000, "version": 0, "expires_at": now + 5 * 3600,
             "rotation": true, "bought": bought]
        }
        // 사람이 올린 글에는 내가 보낸 가격 제안이 걸려 있다.
        let offered = OnlineText.tokens(won: 1_100) ?? 1
        var playerListing = row.merging(["status": "active", "mine": false]) { _, new in new }
        playerListing["unit_tokens"] = OnlineText.tokens(won: 1_500) ?? 1200
        playerListing["my_offer"] = ["id": UUID().uuidString, "version": 0, "quantity": 1, "unit_tokens": offered,
                                     "expires_at": now + 40 * 3600]
        let listings = [playerListing,
                        rotation("sv8pt5-1#normal", bought: false), rotation("me2pt5-295#gold", bought: true)]
        // 돈을 얹은 교환: 카드에 3만 원을 더해 더 좋은 카드를 달라는 제안.
        var moneyTrade = row
        moneyTrade["id"] = UUID().uuidString
        moneyTrade["nickname"] = "얹어 주는 친구"
        moneyTrade["offered_tokens"] = OnlineText.tokens(won: 30_000) ?? 0
        // 내 판매에 온 가격 제안 둘과 내가 보낸 제안 셋(기다리는 중, 수락됨, 거절됨).
        func offer(_ name: String, won: Int, status: String, listing: String) -> [String: Any] {
            ["id": UUID().uuidString, "version": 0, "listing_id": listing, "printing": "\(card)#holo",
             "listing_unit_tokens": OnlineText.tokens(won: 1_500) ?? 1, "quantity": 1,
             "unit_tokens": OnlineText.tokens(won: won) ?? 1, "status": status, "expires_at": now + 30 * 3600,
             "created_at": now - 3600, "nickname": name]
        }
        var mine = playerListing
        mine["mine"] = true
        mine["id"] = UUID().uuidString
        mine.removeValue(forKey: "my_offer")
        let received = [offer("흥정하는 친구", won: 1_200, status: "pending", listing: mine.string("id")),
                        offer("싸게 사고픈 친구", won: 800, status: "pending", listing: mine.string("id"))]
        let sent = [offer("판매자 친구", won: 1_100, status: "pending", listing: "l1"),
                    offer("판매자 친구", won: 1_300, status: "accepted", listing: "l2"),
                    offer("깐깐한 판매자", won: 900, status: "rejected", listing: "l3")]
        model.documents = ["profile": ["profile": profile], "trades": ["items": [row, moneyTrade]], "listings": ["items": listings],
                           "offersReceived": ["items": received], "offersSent": ["items": sent],
                           "notifications": ["items": notes, "order": "desc"], "friends": ["items": friends]]
        model.data = ["totals": ["opened": 1200, "purchased": 1200, "new": 180, "duplicates": 11820], "collection_usd": 3141.59,
                      "variants": ["standard": 1199, "god": 1], "variant_rates": ["god": 1.0 / 1200]]
        model.openingJobs = [RemoteGameSession.OpeningJob(id: UUID().uuidString, set_id: "sv8pt5", total: 2500, completed: 1000,
            version: 1, status: "active", opening_mode: "realistic")]
        func capture(_ name: String, width: CGFloat) async throws {
            let size = NSSize(width: width, height: width == 740 ? 540 : 720)
            let host = NSHostingController(rootView: OnlineHubView(model: model).background(Color(NSColor.windowBackgroundColor)))
            host.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = host
            host.view.setFrameSize(size)
            host.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            host.view.layoutSubtreeIfNeeded()
            guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else { throw LocalAudit.Failure(description: "Online view capture failed") }
            host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw LocalAudit.Failure(description: "Online view encoding failed") }
            try png.write(to: output.appendingPathComponent("\(name)-\(Int(width)).png"))
            window.close()
        }
        for section in [OnlineHubModel.Tab.stats, .social, .trades, .market, .jobs, .alerts] {
            model.section = section
            for width in [CGFloat(740), CGFloat(980)] { try await capture(section.rawValue, width: width) }
        }
        // 알림을 눌러 들어왔을 때: 그 친구 줄과 판매 글에 테두리가 잘리지 않고 둘러져야 한다.
        model.follow(kind: "friend_accept", target: friends[1].string("id"))
        try await capture("social-from-alert", width: 980)
        model.follow(kind: "wishlist_listing", target: row.string("id"), printing: row.string("printing"))
        try await capture("market-from-alert", width: 980)
        model.focus(on: "")
        model.search = ""
        // 내 판매에 온 가격 제안, 내가 보낸 제안. 화면이 새로 그려질 때 들어갈 칸을 정해 둔다.
        let shownListings = model.documents["listings"]
        model.documents["listings"] = ["items": [mine]]
        model.opensMyListings = true
        try await capture("market-mine-offers", width: 980)
        model.documents["listings"] = shownListings
        model.opensSentOffers = true
        try await capture("market-sent-offers", width: 980)
        func capturePicker(_ name: String, _ view: some View) async throws {
            let picker = NSHostingController(rootView: view.background(Color(NSColor.windowBackgroundColor)))
            let pickerSize = picker.view.fittingSize
            let pickerWindow = NSWindow(contentRect: NSRect(origin: .zero, size: pickerSize), styleMask: [.borderless],
                                        backing: .buffered, defer: false)
            pickerWindow.isReleasedWhenClosed = false
            pickerWindow.contentViewController = picker
            picker.view.setFrameSize(pickerSize)
            picker.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            guard let pickerBitmap = picker.view.bitmapImageRepForCachingDisplay(in: picker.view.bounds) else {
                throw LocalAudit.Failure(description: "Stock picker capture failed")
            }
            picker.view.cacheDisplay(in: picker.view.bounds, to: pickerBitmap)
            guard let pickerPNG = pickerBitmap.representation(using: .png, properties: [:]) else {
                throw LocalAudit.Failure(description: "Stock picker encoding failed")
            }
            try pickerPNG.write(to: output.appendingPathComponent("\(name).png"))
            pickerWindow.close()
        }
        // 교환에 담을 카드를 고르는 창. 고르기 전에 카드마다 시세가 보여야 한다.
        let pickable = (CardIndex.shared?.currentCardsByValue.prefix(9) ?? []).enumerated().map { offset, entry in
            let key = "\(entry.id)#holo"
            return OnlineStock(key: key, cardID: entry.id, finish: .holo, available: offset + 1,
                               referenceWon: offset == 4 ? nil : OnlineText.referenceWon(key))
        }
        // 판매 글 창: 남의 글에 가격 제안, 남의 글 바로 사기, 내 글, 이미 한 장 산 봇 매물. 모양은 같고 할 일만 다르다.
        try await capturePicker("buy-offer", BuySheet(model: model, item: playerListing, startsOffering: true)
            .frame(width: 560))
        try await capturePicker("listing-buy", BuySheet(model: model, item: playerListing).frame(width: 560))
        try await capturePicker("listing-mine", BuySheet(model: model, item: mine).frame(width: 560))
        try await capturePicker("listing-bought", BuySheet(model: model, item: listings[2]).frame(width: 560))
        try await capturePicker("trade-picker", OnlineStockPicker(
            wallet: wallet, title: OnlineText.l.addCardsToGive, actionTitle: OnlineText.l.addAction,
            source: pickable) { _, _ in })

        // 교환 칸: 고른 친구에게 남는 카드 가운데 내게 없는 것이 창을 열지 않아도 보여야 한다.
        // 친구에게 남는 아홉 장 가운데 앞의 두 장은 내가 이미 가진 카드로 둔다.
        let partner = friends[1].string("public_id")
        wallet.collect(pickable.prefix(2).map(\.cardID))
        model.friendBinders[partner] = .ready(pickable)
        model.tradeDraft = ["public_id": partner]
        model.section = .trades
        try await capture("trades-missing", width: 980)
        try await capturePicker("friend-binder-picker", OnlineStockPicker(
            wallet: wallet, title: OnlineText.l.friendBinderTitle, actionTitle: OnlineText.l.addAction,
            source: pickable, marksMissing: true) { _, _ in })
        try await capturePicker("friend-binder-picker-missing", OnlineStockPicker(
            wallet: wallet, title: OnlineText.l.friendBinderTitle, actionTitle: OnlineText.l.addAction,
            source: pickable, marksMissing: true, startsMissingOnly: true) { _, _ in })

        model.documents = ["profile": ["profile": profile]]
        model.clearPrivateData()
        try LocalAudit.require(model.documents.isEmpty && model.data.isEmpty, "Logout retained online data")
        OnlineWindow.shared.show(wallet: wallet)
        NSApp.windows.first(where: { $0.title == OnlineText.l.onlineWindowTitle })?.close()
        OnlineWindow.shared.show(wallet: wallet)
        try LocalAudit.require(NSApp.windows.contains(where: { $0.title == OnlineText.l.onlineWindowTitle && $0.isVisible }), "Online window did not reopen")
        NSApp.windows.first(where: { $0.title == OnlineText.l.onlineWindowTitle })?.close()
        print("PASS online native layout: six sections at 740×540 and 980×720, arrivals from alerts, trade card picker, cards missing from a friend, logout cache clearing, close/reopen")
    }
}
