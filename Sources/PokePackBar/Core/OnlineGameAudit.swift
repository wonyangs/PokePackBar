import Foundation

/// Real URLSession client against a disposable server database. Never loads
/// defaults, starts providers, or reads the user's wallet.
@MainActor
enum OnlineGameAudit {
    static func run(address: String) async throws {
        guard let url = URL(string: address), RemoteGameConfiguration.validURL(url),
              ["127.0.0.1", "localhost"].contains(url.host ?? "") else {
            throw LocalAudit.Failure(description: "Audit requires a loopback test server")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-online-audit-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let email = "audit-\(UUID())@example.com"
        let password = UUID().uuidString + UUID().uuidString
        var login = try await ServerAuthentication.login(url: url, email: email, password: password,
            register: true, deviceID: UUID())
        let account = login.account_id
        let configuration = RemoteGameConfiguration(baseURL: url, accountID: account, deviceID: login.device_id)
        let first = RemoteGameSession(configuration: configuration, localRoot: root,
            tokenProvider: { login.access_token })
        var firstState = GameState()
        first.onSnapshot = { firstState = $0 }
        await first.synchronize()
        try LocalAudit.require(first.ready, "Initial sync failed: \(first.error ?? "")")
        first.recordUsage(["audit": 100], date: "2026-09-30", hasData: true)
        first.recordUsage(["audit": 100_000_100], date: "2026-09-30", hasData: true)
        await first.synchronize()
        try LocalAudit.require(firstState.usedSinceInstall == 100_000_000,
            "Trusted collection delta lost: state=\(firstState.usedSinceInstall), ready=\(first.ready), error=\(first.error ?? "none")")
        let bought = await first.execute(.init(kind: "buy_packs", set_id: "sv8pt5", count: 2))
        try LocalAudit.require(bought != nil && firstState.packs["sv8pt5"] == 2, "Purchase failed")
        let opened = await first.execute(.init(kind: "open_packs", set_id: "sv8pt5", count: 1))
        try LocalAudit.require(opened?.packs?.packs.count == 1 && firstState.packs["sv8pt5"] == 1, "Opening failed")
        let secondLogin = try await ServerAuthentication.login(url: url, email: email, password: password,
            register: false, deviceID: UUID())
        try LocalAudit.require(secondLogin.account_id == account, "Login did not recover the same account")
        let second = RemoteGameSession(configuration: .init(baseURL: url, accountID: account, deviceID: secondLogin.device_id),
            localRoot: root.appendingPathComponent("second-device"), tokenProvider: { secondLogin.access_token })
        var secondState = GameState()
        second.onSnapshot = { secondState = $0 }
        await second.synchronize()
        try LocalAudit.require(secondState.cards == firstState.cards && second.revision == first.revision,
                               "Second device did not receive authoritative collection")
        // The first device built its state from command patches; the second fetched it whole.
        let canonical = JSONEncoder()
        canonical.outputFormatting = .sortedKeys
        try LocalAudit.require(try canonical.encode(firstState) == canonical.encode(secondState),
                               "State built from command patches differs from the full server state")
        try LocalAudit.require(first.appliedStatePatches > 0, "Commands never used state patches")

        // Persist a request, commit it through HTTP, then deliberately discard
        // its response as if the app had terminated before receiving it.
        let pending = RemoteGameSession.Request(request_id: UUID(), expected_revision: first.revision,
            command: .init(kind: "open_packs", set_id: "sv8pt5", count: 1), rules_version: ServerRulesBridge.version)
        let body = try JSONEncoder().encode(pending)
        let pendingURL = root.appendingPathComponent("online-\(configuration.storageKey)/pending.json")
        try body.write(to: pendingURL, options: .atomic)
        var request = URLRequest(url: url.appendingPathComponent("v1/commands"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(account.uuidString, forHTTPHeaderField: "X-PPB-Account-ID")
        request.setValue(configuration.deviceID.uuidString, forHTTPHeaderField: "X-PPB-Device-ID")
        let (_, unauthorized) = try await ServerTransport.session.data(for: request)
        try LocalAudit.require((unauthorized as? HTTPURLResponse)?.statusCode == 401, "UUID-only access still allowed")
        request.setValue("Bearer \(login.access_token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await ServerTransport.session.data(for: request)
        try LocalAudit.require((response as? HTTPURLResponse)?.statusCode == 200, "Lost-response setup failed")
        // Revoke after the server committed, before the client recovered its response.
        // Authentication failure must never discard/reissue an uncertain draw.
        _ = try await ServerAuthentication.request(url: url, path: "auth/logout", credential: login)
        let restored = RemoteGameSession(configuration: configuration, localRoot: root,
            tokenProvider: { login.access_token })
        var restoredState = GameState()
        restored.onSnapshot = { restoredState = $0 }
        await restored.synchronize()
        try LocalAudit.require(!restored.ready && restored.hasPending, "Logout discarded pending request")
        login = try await ServerAuthentication.login(url: url, email: email, password: password,
            register: false, deviceID: configuration.deviceID)
        await restored.synchronize()
        try LocalAudit.require(restored.ready && !restored.hasPending && restoredState.packsOpened == 2,
                               "Pending request redrew or lost a pack")
        try LocalAudit.require(restored.recoveredResult?.packs?.packs.count == 1, "Recovered reveal missing")
        let stale = await second.execute(.init(kind: "buy_packs", set_id: "sv8pt5", count: 1))
        try LocalAudit.require(stale == nil && !second.hasPending, "Stale revision accepted")
        await second.synchronize()
        try LocalAudit.require(secondState.cards == restoredState.cards, "Conflict recovery failed")
        try await commerce(address: url, first: restored, root: root)
        try await operations(address: url, credential: login, root: root.appendingPathComponent("operations"))
        _ = try await ServerAuthentication.request(url: url, path: "auth/logout-all", credential: login)
        await second.synchronize()
        try LocalAudit.require(!second.ready, "Logout-all left another device authenticated")
        print("PASS online API: email/password, UUID-only rejection, two devices, collection delta, purchase/open, lost-response restart, logout/re-login replay without redraw, revision conflict, logout-all; isolated account and wallet; no personal Keychain access")
    }

    private static func operations(address: URL, credential: ServerCredential, root: URL) async throws {
        let configuration = RemoteGameConfiguration(baseURL: address, accountID: credential.account_id, deviceID: credential.device_id)
        let remote = RemoteGameSession(configuration: configuration, localRoot: root, tokenProvider: { credential.access_token })
        await remote.synchronize()
        let devices = try await ServerAuthentication.request(url: address, path: "auth/devices", credential: credential, method: "GET")
        try LocalAudit.require(try JSONDecoder().decode(AccountDeviceList.self, from: devices).items.count >= 2, "Device list did not decode")
        let status = try await ServerAuthentication.request(url: address, path: "v1/server/status", credential: credential, method: "GET")
        try LocalAudit.require(try JSONDecoder().decode(AccountJobList.self, from: status).jobs.count == 3, "Server status did not decode")
        let bought = await remote.execute(.init(kind: "buy_packs", set_id: "sv8pt5", count: 1000))
        let extra = await remote.execute(.init(kind: "buy_packs", set_id: "sv8pt5", count: 1))
        try LocalAudit.require(bought != nil && extra != nil, "Opening job purchase failed")
        let job = try await remote.createOpeningJob(setID: "sv8pt5", count: 1001)
        let first = try await remote.advanceOpeningJob(job)
        try LocalAudit.require(first.job.completed == 1000 && first.packs?.packs.count == 1000, "Opening job chunk failed")
        let body = try JSONSerialization.data(withJSONObject: ["request_id": UUID().uuidString,
            "expected_revision": remote.revision, "target_version": first.job.version])
        let path = "v1/opening-jobs/\(job.id)/step"
        let pending = RemoteGameSession.OnlinePending(path: path, body: body)
        let pendingURL = root.appendingPathComponent("online-\(configuration.storageKey)/online-pending.json")
        try JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)
        _ = try await remote.api(path, method: "POST", body: body) // Deliberately lose receipt.
        let recovered = RemoteGameSession(configuration: configuration, localRoot: root, tokenProvider: { credential.access_token })
        await recovered.synchronize()
        try LocalAudit.require(recovered.ready && !recovered.hasOnlinePending, "Opening job replay was not cleared")
        struct Jobs: Decodable { let items: [RemoteGameSession.OpeningJob] }
        let jobs = try JSONDecoder().decode(Jobs.self, from: await recovered.api("v1/opening-jobs")).items
        try LocalAudit.require(jobs.first(where: { $0.id == job.id })?.completed == 1001, "Opening progress duplicated or lost")
        print("PASS native operations: device/status decoding, 1001-pack job, chunk replay after lost response, durable progress")
    }

    /// 친구의 교환 바인더가 그 친구의 남는 카드와 같은지, 역제안이 원래 제안을 닫고 반대로 돌아오는지.
    /// 이 기능이 없는 옛 서버(경로 404)에서는 건너뛴다.
    private static func binderAndCounter(
        first: RemoteGameSession, buyer: RemoteGameSession, friend: String,
        read: (RemoteGameSession, String) async throws -> [String: Any],
        mutate: (RemoteGameSession, String, [String: Any]) async throws -> [String: Any]
    ) async throws -> Bool {
        let binder: [String: Any]
        do { binder = try await read(first, "friends/\(friend)/tradeable") }
        catch let failure as RemoteGameSession.Failure where failure.status == 404 { return false }
        let spares = binder["items"] as? [String: Any] ?? [:]
        let buyerStock = try await read(buyer, "inventory?limit=100")["items"] as? [[String: Any]] ?? []
        let firstStock = try await read(first, "inventory?limit=100")["items"] as? [[String: Any]] ?? []
        guard let wanted = buyerStock.first(where: { $0.int("available") >= 2 }),
              let given = firstStock.first(where: { $0.int("available") >= 1 && $0.string("printing") != wanted.string("printing") }) else {
            throw LocalAudit.Failure(description: "Missing spare printings for the counter-offer check")
        }
        let want = wanted.string("printing"), give = given.string("printing")
        try LocalAudit.require((spares[want] as? NSNumber)?.intValue == wanted.int("available"),
                               "Trade binder does not match the friend's spare cards")
        let proposal = try await mutate(first, "trades", ["action": "trade_create", "target_id": friend,
            "offered": [["printing": give, "quantity": 1]], "requested": [["printing": want, "quantity": 1]]])
        let proposalID = (proposal["result"] as? [String: Any])?.string("id") ?? ""
        let counter = try await mutate(buyer, "trades", ["action": "trade_counter", "target_id": proposalID, "target_version": 0,
            "offered": [["printing": want, "quantity": 2]], "requested": [["printing": give, "quantity": 1]]])
        let counterID = (counter["result"] as? [String: Any])?.string("id") ?? ""
        let trades = try await read(first, "trades")["items"] as? [[String: Any]] ?? []
        try LocalAudit.require(trades.first { $0.string("id") == proposalID }?.string("status") == "countered",
                               "Countered offer was not closed")
        let answer = trades.first { $0.string("id") == counterID }
        try LocalAudit.require(answer?.string("counter_of") == proposalID && answer?.bool("incoming") == true,
                               "Counter-offer did not come back to the original sender")
        await first.synchronize()
        try LocalAudit.require(first.reservedPrintings[give] == nil, "Countered offer kept its held cards")
        _ = try await mutate(first, "trades", ["action": "trade_accept", "target_id": counterID, "target_version": 0])
        await buyer.synchronize()
        try LocalAudit.require(buyer.reservedPrintings.isEmpty, "Accepted counter-offer kept its held cards")
        return true
    }

    private static func commerce(address: URL, first: RemoteGameSession, root: URL) async throws {
        let login = try await ServerAuthentication.login(url: address, email: "buyer-\(UUID())@example.com",
            password: UUID().uuidString + UUID().uuidString, register: true, deviceID: UUID())
        let buyer = RemoteGameSession(configuration: .init(baseURL: address, accountID: login.account_id, deviceID: login.device_id),
            localRoot: root.appendingPathComponent("buyer"), tokenProvider: { login.access_token })
        await buyer.synchronize()
        func read(_ session: RemoteGameSession, _ path: String) async throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: await session.api("v1/" + path)) as? [String: Any] ?? [:]
        }
        func mutate(_ session: RemoteGameSession, _ path: String, _ values: [String: Any]) async throws -> [String: Any] {
            await session.synchronize()
            let body = values.merging(["request_id": UUID().uuidString, "expected_revision": session.revision]) { _, new in new }
            let data = try await session.onlineMutation(path: "v1/" + path, body: JSONSerialization.data(withJSONObject: body))
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
        for session in [first, buyer] {
            _ = await session.execute(.init(kind: "report_tokens", collected_total: 10_000_000_000))
            let purchase = await session.execute(.init(kind: "buy_packs", set_id: "sv8pt5", count: 50))
            try LocalAudit.require(purchase != nil, "Commerce fixture purchase failed")
            let opened = await session.execute(.init(kind: "open_packs", set_id: "sv8pt5", count: 50))
            try LocalAudit.require(opened?.packs?.packs.count == 50, "Commerce fixture opening failed")
            _ = try await read(session, "profile")
        }
        let profile = try await read(buyer, "profile")["profile"] as? [String: Any] ?? [:]
        let friendship = try await mutate(first, "friends", ["action": "friend_request", "friend_code": profile.string("friend_code")])
        let friendID = (friendship["result"] as? [String: Any])?.string("id") ?? ""
        _ = try await mutate(buyer, "friends", ["action": "friend_accept", "target_id": friendID, "target_version": 0])
        let firstInventory = try await read(first, "inventory?limit=100")["items"] as? [[String: Any]] ?? []
        let secondInventory = try await read(buyer, "inventory?limit=100")["items"] as? [[String: Any]] ?? []
        guard let offered = firstInventory.first(where: { $0.int("available") >= 2 })?.string("printing"),
              let requested = secondInventory.first(where: { $0.int("available") >= 1 && $0.string("printing") != offered })?.string("printing") else {
            throw LocalAudit.Failure(description: "Missing duplicate test printings")
        }
        let trade = try await mutate(first, "trades", ["action": "trade_create", "target_id": profile.string("public_id"),
            "offered": [["printing": offered, "quantity": 2]], "requested": [["printing": requested, "quantity": 1]]])
        try LocalAudit.require(first.reservedPrintings[offered] == 2, "Reservation snapshot not applied")
        let tradeID = (trade["result"] as? [String: Any])?.string("id") ?? ""
        // The recipient learns about the offer from the menu bar summary, then answers it.
        await buyer.refreshNotificationSummary()
        if let summary = buyer.notificationSummary {
            try LocalAudit.require(summary.incoming_trades == 1, "Trade offer missing from the notification summary")
        }
        _ = try await mutate(buyer, "trades", ["action": "trade_accept", "target_id": tradeID, "target_version": 0])
        await buyer.refreshNotificationSummary()
        if let summary = buyer.notificationSummary {
            try LocalAudit.require(summary.incoming_trades == 0, "Accepted trade still counted as pending")
        }
        await first.synchronize()
        try LocalAudit.require(first.reservedPrintings.isEmpty, "Completed trade retained reservation")
        let binderChecked = try await binderAndCounter(first: first, buyer: buyer, friend: profile.string("public_id"),
                                                       read: read, mutate: mutate)
        // Counter-offers may consume the original offered spare. Choose from the
        // current authoritative stock, not the pre-trade fixture inventory.
        let listingStock = try await read(buyer, "inventory?limit=100")["items"] as? [[String: Any]] ?? []
        guard let listingPrinting = fixtureListingPrinting(stock: listingStock, preferred: offered) else {
            throw LocalAudit.Failure(description: "No remaining spare for marketplace fixture")
        }
        let listing = try await mutate(buyer, "market/listings", ["action": "listing_create", "printing": listingPrinting, "quantity": 1, "unit_tokens": 123])
        let listingID = (listing["result"] as? [String: Any])?.string("id") ?? ""
        await first.synchronize()
        let body = try JSONSerialization.data(withJSONObject: ["action": "listing_buy", "target_id": listingID,
            "target_version": 0, "quantity": 1, "unit_tokens": 123, "request_id": UUID().uuidString, "expected_revision": first.revision])
        // Server committed, client receipt deliberately lost. Disk replay must settle once.
        let pending = RemoteGameSession.OnlinePending(path: "v1/market/listings", body: body)
        let pendingURL = root.appendingPathComponent("online-\(first.configuration.storageKey)/online-pending.json")
        try JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)
        _ = try await first.api(pending.path, method: "POST", body: body)
        // Replay through the same public client API then verify that a repeated ID is unchanged.
        let repeatedData = try await first.onlineMutation(path: pending.path, body: body)
        let repeated = try JSONSerialization.jsonObject(with: repeatedData) as? [String: Any] ?? [:]
        try LocalAudit.require(repeated.bool("replayed") && !first.hasOnlinePending, "Marketplace lost-response replay failed")
        let final = try await read(first, "state")["state"] as? [String: Any] ?? [:]
        try LocalAudit.require(final.int("marketSpentTokens") == 123, "Marketplace debit duplicated")
        let binderNote = binderChecked ? "trade binder, counter-offer" : "trade binder and counter-offer skipped (server without them)"
        print("PASS native commerce: friend approval, printing reservations, trade acceptance, \(binderNote), marketplace purchase, durable receipt replay, no double debit")
    }

    static func fixtureListingPrinting(stock: [[String: Any]], preferred: String) -> String? {
        let available = stock.filter { $0.int("available") >= 1 }
        return (available.first { $0.string("printing") == preferred } ?? available.first)?.string("printing")
    }
}
