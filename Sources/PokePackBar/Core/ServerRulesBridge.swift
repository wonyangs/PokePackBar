import Foundation

/// Server-only stdin/stdout evaluator. No networking, user wallet, provider
/// credentials, menu bar or update tasks. FastAPI owns the durable transaction.
@MainActor
enum ServerRulesBridge {
    struct Command: Codable, Sendable {
        var kind: String
        var set_id: String?
        var count: Int?
        var card_id: String?
        var card_ids: [String]?
        var dex_id: String?
        var step: Int?
        var gift_id: String?
        var envelope: Int?
        var opening_mode: String?
        var favorite_card_id: String?
        var title: Int?
        var collected_total: Int?
        var windows: [Window]?
        var quote_kind: String?
        var remove: [String: Int]?
        var add: [String: Int]?
        var market_credit: Int?
        var market_debit: Int?
        /// 로테이션 마켓 진열의 날짜(UTC `yyyy-MM-dd`).
        var date: String?
        /// 고른 레벨 칭호. 도감 칭호(`title`)와 둘 중 하나만 단다.
        var level_title: Int?
    }
    struct Window: Codable, Sendable {
        let key: String
        let name: String
        let kind: String
        let utilization: Double
        let instance: String
    }
    struct Input: Decodable { let state: GameState; let command: Command; var protected: [String: Int]? }
    struct OripaResult: Codable { let card: PulledCard; let completions: [DexCompletion] }
    struct Result: Codable {
        var packs: OpenedPackBatch?
        var tokens: Int?
        var sold: Int?
        var dex: DexClaim?
        var oripa: OripaResult?
        var bulk: WalletStore.BulkSale?
        var value_usd: Double?
        /// 이번에 받은 레벨 보상의 레벨들.
        var levels: [Int]?
        /// 로테이션 마켓에서 산 카드.
        var rotation: PulledCard?
    }
    struct Output: Encodable {
        let state: GameState
        let result: Result
        let rules_version: String
    }
    static var version: String {
        let dexData = AppResources.bundle?.url(forResource: "dex", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) } ?? Data()
        let inputs = [OpeningRules.version, OpeningRules.catalogueDigest, OpeningRules.digest(dexData),
                      PackOdds.digest]
        return "ppb-server-v2/" + OpeningRules.digest(Data(inputs.joined(separator: "/").utf8))
    }

    static func run() throws {
        if let path = AppEnv.value("PPB_RULE_PRICES") {
            _ = try PriceSnapshotStore.validate(PriceSnapshotStore.read(URL(fileURLWithPath: path)))
        }
        guard let index = CardIndex.shared, CardPrices.shared != nil else {
            throw LocalAudit.Failure(description: "Missing server rule resources")
        }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard data.count <= 16 * 1024 * 1024 else {
            throw LocalAudit.Failure(description: "Rule input too large")
        }
        let input = try JSONDecoder().decode(Input.self, from: data)
        let encoded = try JSONEncoder().encode(input.state)
        _ = try GamePersistence.decode(encoded)
        guard input.state.cards.keys.allSatisfy({ index.card($0) != nil }),
              input.state.packs.keys.allSatisfy({ id in index.sets.contains { $0.id == id } }) else {
            throw LocalAudit.Failure(description: "Unknown collection resource")
        }
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("ppb-rules-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let file = temporary.appendingPathComponent("game-state.json")
        try encoded.write(to: file)
        let wallet = WalletStore(fileURL: file, commitState: { _ in })
        wallet.protectedPrintings = input.protected ?? [:]
        wallet.normalizeServerPrintings()
        let command = input.command
        var result = Result()
        func require(_ condition: Bool) throws {
            if !condition { throw LocalAudit.Failure(description: "Command precondition failed") }
        }
        switch command.kind {
        case "inspect": break
        case "valuation": result.value_usd = wallet.collectionValueUSD()
        case "transfer":
            let changes = (command.remove ?? [:]).merging(command.add ?? [:]) { left, right in max(left, right) }
            try require(changes.count <= 40 && changes.values.allSatisfy { (1...1000).contains($0) })
            for key in changes.keys {
                let printing = CardPrintingKey(storageKey: key)
                try require(printing.storageKey == key && index.card(printing.cardID) != nil)
            }
            try wallet.serverTransfer(remove: command.remove ?? [:], add: command.add ?? [:],
                credit: command.market_credit ?? 0, debit: command.market_debit ?? 0)
        case "quote":
            switch command.quote_kind {
            case "buy_packs":
                guard let id = command.set_id, let count = command.count, count > 0 else {
                    throw LocalAudit.Failure(description: "Invalid quote")
                }
                result.tokens = wallet.packTotal(setID: id, count: count, index: index)
            case "sell_spares": result.tokens = wallet.serverSaleQuote(cardID: command.card_id ?? "", count: command.count ?? 0)
            case "sell_bulk": result.tokens = (command.card_ids ?? []).reduce(0) { $0 + wallet.spareSaleValue(cardID: $1) }
            case "pull_oripa": result.tokens = wallet.oripaPrice(index: index)
            case "refresh_oripa": result.tokens = 0
            case "rotation_buy":
                guard let id = command.card_id, index.card(id) != nil else {
                    throw LocalAudit.Failure(description: "Invalid quote")
                }
                result.tokens = wallet.rotationPrice(id, index: index)
            default: throw LocalAudit.Failure(description: "Invalid quote kind")
            }
        case "apply_tokens":
            guard let delta = command.collected_total, (0...1_000_000_000_000_000).contains(delta) else {
                throw LocalAudit.Failure(description: "Invalid token delta")
            }
            wallet.creditReportedTokens(delta)
        case "initialize":
            for gift in [WalletStore.apologyGift, WalletStore.patchGift,
                         WalletStore.oripaUpdateGift, WalletStore.dexUpdateGift] {
                wallet.claim(gift, index: index)
            }
            _ = wallet.oripaBox(index: index)
        case "buy_packs", "open_packs":
            guard let id = command.set_id, index.sets.contains(where: { $0.id == id }),
                  let count = command.count, (1...1000).contains(count) else {
                throw LocalAudit.Failure(description: "Invalid pack command")
            }
            if command.kind == "buy_packs" {
                try require(wallet.buyPacks(setID: id, count: count,
                    total: wallet.packTotal(setID: id, count: count, index: index)))
            } else {
                result.packs = wallet.openPacks(setID: id, count: count, index: index)
                try require(result.packs != nil)
            }
        case "sell_spares":
            guard let id = command.card_id, let card = index.card(id),
                  let count = command.count, (1...1000).contains(count),
                  wallet.cardCount(id) > count else {
                throw LocalAudit.Failure(description: "Not enough duplicate cards")
            }
            let before = wallet.cardCount(id)
            result.tokens = wallet.sellSpares(cardID: id, tier: card.tier, count: count)
            result.sold = before - wallet.cardCount(id)
            try require(result.sold == count)
        case "sell_bulk":
            guard let ids = command.card_ids, ids.count <= 1000,
                  Set(ids).count == ids.count, ids.allSatisfy({ index.card($0) != nil }) else {
                throw LocalAudit.Failure(description: "Invalid bulk sale")
            }
            let before = wallet.state.cardsDisenchanted
            result.bulk = wallet.sellSpares(ids)
            result.tokens = wallet.state.refundedTokens - input.state.refundedTokens
            result.sold = wallet.state.cardsDisenchanted - before
        case "claim_dex":
            result.dex = wallet.claim(command.dex_id ?? "", step: command.step ?? 0, index: index)
            try require(result.dex != nil)
        case "claim_levels":
            let rewards = wallet.claimLevels()
            try require(!rewards.isEmpty)
            result.levels = rewards.map(\.level)
        case "rotation_buy":
            guard let id = command.card_id, let date = command.date,
                  let card = wallet.buyRotation(cardID: id, index: index, date: date) else {
                throw LocalAudit.Failure(description: "Rotation card unavailable or insufficient balance")
            }
            result.rotation = card
        case "claim_gift":
            let gifts = [WalletStore.apologyGift, WalletStore.patchGift,
                         WalletStore.oripaUpdateGift, WalletStore.dexUpdateGift]
            guard let gift = gifts.first(where: { $0.id == command.gift_id }) else {
                throw LocalAudit.Failure(description: "Unknown gift")
            }
            wallet.claim(gift, index: index)
        case "refresh_oripa": wallet.replaceOripaBox(index: index)
        case "pull_oripa":
            guard let envelope = command.envelope,
                  let opened = wallet.pullOripa(index: index, envelope: envelope) else {
                throw LocalAudit.Failure(description: "Envelope unavailable or insufficient balance")
            }
            result.oripa = OripaResult(card: opened.card, completions: opened.completions)
        case "set_preferences":
            guard let mode = OpeningMode(rawValue: command.opening_mode ?? ""),
                  command.favorite_card_id.map({ wallet.cardCount($0) > 0 }) ?? true,
                  command.title.map({ value in wallet.titles.contains { $0.completed == value } }) ?? true,
                  command.level_title.map({ wallet.levelTitles.contains($0) }) ?? true,
                  command.title == nil || command.level_title == nil else {
                throw LocalAudit.Failure(description: "Unavailable preference")
            }
            wallet.setOpeningMode(mode)
            wallet.setFavorite(command.favorite_card_id)
            wallet.setTitle(command.title)
            wallet.setLevelTitle(command.level_title)
        case "report_bonus":
            let windows = (command.windows ?? []).map {
                BonusWindow(key: $0.key, name: $0.name,
                    kind: $0.kind == "weekly" ? .weekly : .session,
                    utilization: $0.utilization, instance: $0.instance)
            }
            let sets = index.sets.map { BonusSet(id: $0.id,
                price: PackPricing.basePrice(setID: $0.id, index: index, prices: CardPrices.shared)) }
            _ = wallet.grantBonusPacks(from: windows, limitsReady: true, availableSets: sets)
        default: throw LocalAudit.Failure(description: "Unknown rule command")
        }
        try require(wallet.persistenceError == nil)
        let output = Output(state: wallet.state, result: result, rules_version: version)
        FileHandle.standardOutput.write(try JSONEncoder().encode(output))
    }
}
