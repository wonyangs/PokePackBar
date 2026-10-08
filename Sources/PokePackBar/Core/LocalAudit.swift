import AppKit
import Foundation

/// Release-binary checks work even on a Mac with CommandLineTools but no XCTest.
/// This entry point runs before WalletStore/default paths or application startup.
@MainActor
enum LocalAudit {
    struct Failure: Error, CustomStringConvertible { let description: String }
    nonisolated static func require(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
        if try !condition() { throw Failure(description: label) }
    }

    static func run(_ args: [String]) throws -> Bool {
        guard args.contains("--audit-local") || args.contains("--export-online-catalogue") || args.contains("--export-printing-map") || args.contains("--export-foil-map")
                || args.contains("--simulate-packs") || args.contains("--replay-openings")
                || args.contains("--audit-image-library") || args.contains("--audit-foil-geometry")
                || args.contains("--audit-confirmed-foil-fixes") || args.contains("--audit-price-snapshot")
                || args.contains("--audit-korean-names") || args.contains("--audit-foil-optics")
                || args.contains("--audit-reviewed-foil") || args.contains("--audit-physical-pack-cards")
                || args.contains("--dex-metrics") else { return false }
        guard let index = CardIndex.shared else { throw Failure(description: "Missing card index") }
        if args.contains("--dex-metrics") {
            try DexMetrics.run()
            return true
        }
        if args.contains("--export-online-catalogue") {
            let entries = index.cards.map { card in
                ["id": card.id, "name": card.name, "name_ko": card.displayName(.ko),
                 "tier": card.tier.rawValue, "set_id": card.setID]
            }
            print(String(decoding: try JSONEncoder().encode(entries), as: UTF8.self))
            return true
        }
        if args.contains("--audit-physical-pack-cards") {
            try auditPhysicalPackCards(index)
            return true
        }
        if args.contains("--audit-reviewed-foil") {
            try ReviewedFoilAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-foil-optics") {
            try FoilOpticsAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-korean-names") {
            try KoreanNameAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-price-snapshot") {
            try PriceSnapshotAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-confirmed-foil-fixes") {
            try ConfirmedFoilAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-foil-geometry") {
            try FoilGeometry.verify(index: index)
            try ExpansionFoil.verify(index: index)
            try FoilSubjectMasks.verify()
            try PhysicalFoilMarks.verify()
            let first = NSImage(size: NSSize(width: 660, height: 920))
            let replacement = NSImage(size: NSSize(width: 660, height: 920))
            let art = CGRect(x: 0.08, y: 0.10, width: 0.84, height: 0.37)
            try require(ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: art)
                != ArtworkMaskCache.key(cardID: "cel30-1", source: replacement, art: art),
                "Replacement original reused old segmentation")
            try require(ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: art)
                != ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: .zero),
                "Changed illustration crop reused old segmentation")
            print("PASS foil geometry: \(index.cards.count) original hashes/layouts at 180/240/420pt; wallet untouched")
            return true
        }
        if args.contains("--audit-image-library") {
            let count = try CardArtLibrary.verify(index: index, hashes: true)
            // Exercise the real loader against small/preloaded and corrupt
            // input, not just the on-disk filenames or CDN size parameters.
            try require(!CardArtLibrary.accepts(Data("not an image".utf8), hires: true), "Corrupt image accepted")
            for id in ["base1-4", "me2-130", "me2pt5-295", "cel30-158", "cel30c-1", "cel30c-9", "cel30c-19"] {
                guard let data = CardArtLibrary.data(id),
                      let small = CardArtLibrary.image(data, hires: false),
                      let large = CardImageLoader.cachedImage(cardID: id, hires: true)
                else { throw Failure(description: "Offline loader failed: \(id)") }
                try require(!CardArtLibrary.isHighResolution(small), "Grid image was not downsampled")
                try require(CardArtLibrary.isHighResolution(large), "Detail retained thumbnail: \(id)")
                try require(large.size.width < large.size.height, "Landscape scan was cropped or stretched: \(id)")
            }
            print("PASS offline image library: \(count) decoded dimensions + SHA-256; real grid/detail loader; wallet untouched")
            return true
        }
        if args.contains("--export-foil-map") {
            struct Sample: Encodable {
                let cardID: String
                let finish: CardFinish
                let spec: FoilSpec
                let opticalMaterial: String?
            }
            var samples: [String: Sample] = [:]
            for card in index.cards {
                for finish in FoilAuditPrintings.finishes(for: card, index: index) {
                    let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                        originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind, explicitFinish: finish)
                    guard resolved.spec.isFoil else { continue }
                    let s = resolved.spec
                    let key = args.contains("--all-cards") ? "\(card.id)#\(resolved.finish.rawValue)" : "\(resolved.finish.rawValue)/\(s.coverage.rawValue)/\(s.pattern.rawValue)/\(s.texture.rawValue)/\(s.border.rawValue)/\(s.intensity)/\(s.treatment?.rawValue ?? "legacy")"
                    if samples[key] == nil {
                        samples[key] = Sample(cardID: card.id, finish: resolved.finish, spec: s,
                            opticalMaterial: ReviewedFoilProfiles.entry(cardID: card.id, finish: resolved.finish)
                                .map { "reviewed-" + $0.layers.map(\.material.rawValue).joined(separator: "+") }
                                ?? FoilSheetMaterial(pattern: s.pattern, cardID: card.id).map { "sheet-\($0.rawValue)" }
                                ?? FoilOpticsAudit.material(card.id, s)?.cacheKey)
                    }
                }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            print(String(decoding: try encoder.encode(samples), as: UTF8.self))
            return true
        }
        if args.contains("--export-printing-map") {
            let map = Dictionary(uniqueKeysWithValues: index.cards.map { card in
                (card.id, CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                    originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind).finish.rawValue)
            })
            print(String(decoding: try JSONEncoder().encode(map), as: UTF8.self))
            return true
        }
        if let at = args.firstIndex(of: "--replay-openings") {
            guard args.count > at + 1 else { throw Failure(description: "Expected history JSON path") }
            let data = try Data(contentsOf: URL(fileURLWithPath: args[at + 1]))
            let records = try JSONDecoder().decode([OpeningRecord].self, from: data)
            for record in records {
                try require(record.rulesVersion == OpeningRules.version && record.catalogueDigest == OpeningRules.catalogueDigest,
                            "Rules/catalogue mismatch: use the recorded app version, not current rules")
                guard let seed = UInt64(record.seed) else { throw Failure(description: "Invalid seed") }
                var generator = PackSeedGenerator(seed: seed)
                var pity = record.pityBefore
                let result = PackOpening.draw(setID: record.setID, index: index, alreadyOwned: [],
                    perks: DexPerks(hitOdds: record.hitOddsBonus), pity: &pity,
                    mode: record.mode, using: &generator)
                try require(result.variant == record.variant && pity == record.pityAfter &&
                    result.cards.map { CardPrintingKey(cardID: $0.id, finish: $0.finish) } == record.printings,
                    "Replay mismatch: \(record.id)")
            }
            print("PASS replay: \(records.count) openings; live wallet untouched")
            return true
        }
        if let at = args.firstIndex(of: "--simulate-packs") {
            guard args.count > at + 3, let count = Int(args[at + 2]), (1...1_000_000).contains(count),
                  let seed = UInt64(args[at + 3]), index.set(args[at + 1]) != nil
            else { throw Failure(description: "Usage: --simulate-packs SET COUNT(1...1000000) SEED [--game]") }
            try simulate(index: index, setID: args[at + 1], count: count, seed: seed,
                         mode: args.contains("--game") ? .game : .realistic)
            return true
        }
        try audit(index)
        return true
    }

    static func simulate(index: CardIndex, setID: String, count: Int, seed: UInt64, mode: OpeningMode) throws {
        var rng = PackSeedGenerator(seed: seed)
        var pity = 0
        var variants: [String: Int] = [:]
        var tiers: [String: Int] = [:]
        let prices = CardPrices.shared
        var valueSum = 0.0
        var valueSquares = 0.0
        let expected = PackRecipe.forSet(setID, era: index.era(setID)).contents.gameCardCount
        for _ in 0..<count {
            let result = PackOpening.draw(setID: setID, index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                pity: &pity, mode: mode, using: &rng)
            try require(result.cards.count == expected, "Wrong card count: \(setID)")
            variants[result.variant.rawValue, default: 0] += 1
            for card in result.cards { tiers[card.tier.rawValue, default: 0] += 1 }
            let value = result.cards.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1.id, finish: $1.finish, prices: prices) }
            valueSum += value
            valueSquares += value * value
        }
        let mean = valueSum / Double(count)
        let standardError = sqrt(max(0, valueSquares / Double(count) - mean * mean) / Double(count))
        let result: [String: Any] = ["setID": setID, "packs": count, "seed": String(seed),
            "rulesVersion": OpeningRules.version, "mode": mode.rawValue, "variants": variants, "tiers": tiers,
            "sampleMeanUSD": mean, "sampleStandardErrorUSD": standardError,
            "noPityModelEVUSD": MarketEconomy.packValueUSD(setID: setID, index: index, prices: prices)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }

    static func audit(_ index: CardIndex) throws {
        try auditCodexIncrementalParsing()
        try auditDexCardSearch(index)
        try auditUnlimitedBulkSale(index)
        try auditPhysicalPackCards(index)
        if index.set("cel30") != nil {
            try require(index.cards.filter { $0.setID == "me2pt5" && $0.visualKind?.isTera == true }.count == 7,
                        "Ascended Heroes printed Tera labels were lost")
            var generator = PackSeedGenerator(seed: 20260923)
            var pity = 0
            var seen: Set<String> = []
            for _ in 0..<10_000 {
                let result = PackOpening.draw(setID: "cel30", index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                    pity: &pity, mode: .realistic, using: &generator)
                try require(result.cards.count == 5 && !result.variant.isGodPack, "30th physical composition failed")
                try require(result.cards.filter { index.card($0.id)?.rarity == "Pikachu Rare" }.count == 1,
                            "30th must contain exactly one Pikachu Rare")
                try require(result.cards.allSatisfy { $0.finish != .normal }, "30th contains a non-foil printing")
                try require(result.cards.filter { $0.tier.rank > CardTier.rare.rank
                                && index.card($0.id)?.rarity != "Pikachu Rare" }.count <= 2,
                            "30th has more than one IR/Classic and one Rare-position hit")
                seen.formUnion(result.cards.map(\.id))
            }
            // RGB Mew is about 1 in 3,300 packs, so a sample cannot prove it is reachable.
            // Every card must instead sit in some position's pool with a positive weight.
            let recipe = PackRecipe.forSet("cel30", era: .scarletViolet)
            var reachable = Set<String>()
            for (slot, table) in zip(recipe.slots, PackConfig.slotTables(setID: "cel30", era: .scarletViolet)) {
                let slotPool = PackOpening.slotPool(setID: "cel30", slot: slot.kind,
                                                    pool: index.pools["cel30"] ?? [:], index: index)
                for entry in table.weights where entry.weight > 0 {
                    reachable.formUnion(slotPool[entry.tier] ?? [])
                }
            }
            try require(seen.isSubset(of: reachable)
                        && index.cards.filter { $0.setID == "cel30" }.allSatisfy { reachable.contains($0.id) },
                        "30th checklist has unreachable cards")
            let megaAttack = PackOpening.slotPool(setID: "me2pt5", slot: .rare,
                pool: index.pools["me2pt5"] ?? [:], index: index)[.megaAttack] ?? []
            try require(megaAttack.count == 7 && PackConfig.slotTables(setID: "me2pt5", era: .scarletViolet)
                .contains { $0.weights.contains { $0.tier == .megaAttack && $0.weight > 0 } }, "Mega Attack cannot be drawn")
            print("PASS latest catalogue: 10,000 anniversary packs, exact Pikachu slot, all foil, complete reachability, 7 Mega Attack cards")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-regression-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game-state.json")
        let persistence = GamePersistence(url: url)
        var initial = GameState()
        initial.usedSinceInstall = 9_000_000_000
        initial.packs = ["sv8pt5": 3]
        try persistence.commit(initial)
        var fails = false
        var commits = 0
        let wallet = WalletStore(fileURL: url, dexes: [], ladder: [], commitState: { state in
            commits += 1
            if fails { throw Failure(description: "Injected disk write failure") }
            try persistence.commit(state)
        })
        try require(PackQuantitySelection.validated(" 37 ", maximum: 100) == 37,
                    "Direct quantity input rejected a valid value")
        try require(PackQuantitySelection.validated("0", maximum: 100) == nil
                    && PackQuantitySelection.validated("101", maximum: 100) == nil,
                    "Direct quantity input accepted an out-of-range value")
        try require(wallet.maximumAffordablePackCount(setID: "sv8pt5", index: index) > 20,
                    "Affordable purchase quantity is still capped at 20")
        let before = wallet.availableTokens
        commits = 0
        try require(wallet.buyPacks(setID: "sv8pt5", count: 2, total: 1_000), "Purchase failed")
        try require(commits == 1 && wallet.availableTokens == before - 1_000 && wallet.packCount(setID: "sv8pt5") == 5, "Purchase is not one commit")
        fails = true
        try require(!wallet.buyPacks(setID: "sv8pt5", count: 2, total: 1_000), "Failed purchase reported success")
        try require(wallet.packCount(setID: "sv8pt5") == 5 && wallet.availableTokens == before - 1_000, "Purchase rollback failed")
        try require(wallet.openPack(setID: "sv8pt5", index: index, seed: 11) == nil, "Failed opening reported success")
        try require(wallet.packCount(setID: "sv8pt5") == 5 && wallet.state.cards.isEmpty && wallet.state.openingHistory.isEmpty,
                    "Opening rollback failed")
        try require(wallet.openPacks(setID: "sv8pt5", count: 3, index: index,
                                     seeds: [21, 22, 23]) == nil,
                    "Failed batch opening reported success")
        try require(wallet.packCount(setID: "sv8pt5") == 5 && wallet.state.cards.isEmpty
                    && wallet.state.openingHistory.isEmpty && wallet.state.packsOpened == 0,
                    "Batch opening rollback failed")
        try require(wallet.pullOripa(index: index, envelope: 0) == nil, "Failed Oripa reported success")
        try require(wallet.state.oripa == nil && wallet.state.cards.isEmpty && wallet.availableTokens == before - 1_000,
                    "Oripa rollback failed")
        fails = false
        commits = 0
        guard let opened = wallet.openPack(setID: "sv8pt5", index: index, seed: 11),
              let record = wallet.state.openingHistory.last else { throw Failure(description: "Opening failed") }
        try require(commits == 1 && opened.opened.cards.count == 10, "Opening is not one commit")
        var replay = PackSeedGenerator(seed: 11)
        var pity = record.pityBefore
        let result = PackOpening.draw(setID: record.setID, index: index, alreadyOwned: [], pity: &pity,  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                                      mode: record.mode, using: &replay)
        try require(result.cards.map { CardPrintingKey(cardID: $0.id, finish: $0.finish) } == record.printings,
                    "Seed replay differs")
        commits = 0
        guard let batch = wallet.openPacks(setID: "sv8pt5", count: 3, index: index,
                                           seeds: [21, 22, 23]) else {
            throw Failure(description: "Batch opening failed")
        }
        try require(commits == 1 && batch.packs.count == 3 && batch.cards.count == 30,
                    "Batch opening is not one commit")
        try require(wallet.packCount(setID: "sv8pt5") == 1 && wallet.state.packsOpened == 4
                    && wallet.state.openingHistory.count == 4,
                    "Batch opening inventory or history differs")
        try require(wallet.state.openingHistory.suffix(3).map(\.seed) == ["21", "22", "23"],
                    "Batch opening seeds were not recorded per pack")
        let historyURL = directory.appendingPathComponent("history.json")
        try JSONEncoder().encode(wallet.state.openingHistory).write(to: historyURL)
        try require(try run(["--replay-openings", historyURL.path]), "History replay command failed")
        let bytes = try Data(contentsOf: url)
        for _ in 0..<12 { try persistence.commit(wallet.state) }
        try require(try persistence.backupURLs().count == GamePersistence.retainedBackups, "Backup rotation failed")
        try Data("invalid".utf8).write(to: url, options: .atomic)
        let restored = try persistence.load()
        try require(restored.recovered && restored.state.packs == wallet.state.packs, "Recovery failed")
        try require(try Data(contentsOf: url) == bytes, "Recovery altered save")
        print("PASS purchase/open/batch atomic commit, injected failure rollback, seed replay, 8 backups, corruption recovery")

        let largeBatchURL = directory.appendingPathComponent("large-batch.json")
        var largeBatchState = GameState()
        largeBatchState.packs = ["sv8pt5": 12]
        try GamePersistence(url: largeBatchURL).commit(largeBatchState)
        let largeBatchWallet = WalletStore(fileURL: largeBatchURL, dexes: [], ladder: [])
        let largeBatchSeeds = (0..<12).map { UInt64(500 + $0) }
        guard let largeBatch = largeBatchWallet.openPacks(
            setID: "sv8pt5",
            count: 12,
            index: index,
            seeds: largeBatchSeeds
        ) else { throw Failure(description: "12-pack opening failed") }
        try require(largeBatch.packs.count == 12 && largeBatchWallet.packCount(setID: "sv8pt5") == 0,
                    "Opening quantity is still capped at 10")
        largeBatchWallet.markAllRevealed()
        let referenceValue = largeBatchWallet.state.cards.keys.reduce(0.0) { total, cardID in
            total + largeBatchWallet.ownedPrintings(cardID: cardID).reduce(0.0) {
                $0 + MarketEconomy.usd($1.printing, prices: CardPrices.shared) * Double($1.count)
            }
        }
        try require(abs(largeBatchWallet.collectionValueUSD() - referenceValue) < 0.000001,
                    "Linear collection value differs from printing-by-printing reference")
        print("PASS pack quantity: direct input validation, >20 affordable purchase, 12-pack opening; linear collection value parity")

        let blockedDirectory = directory.appendingPathComponent("blocked")
        try FileManager.default.createDirectory(at: blockedDirectory, withIntermediateDirectories: true)
        let blockedURL = blockedDirectory.appendingPathComponent("game-state.json")
        let blockedPersistence = GamePersistence(url: blockedURL)
        try blockedPersistence.commit(initial)
        // A real filesystem failure, not just the injected closure: a regular
        // file prevents creating the backup directory, so the original remains.
        try Data("not a directory".utf8).write(to: blockedPersistence.backupDirectory)
        let blockedWallet = WalletStore(fileURL: blockedURL, dexes: [], ladder: [])
        try require(!blockedWallet.buyPacks(setID: "sv8pt5", count: 1, total: 1_000), "Disk failure reported success")
        try require(blockedWallet.availableTokens == initial.usedSinceInstall && blockedWallet.packCount(setID: "sv8pt5") == 3,
                    "Disk failure changed wallet")
        let corruptURL = directory.appendingPathComponent("unrecoverable/game-state.json")
        try FileManager.default.createDirectory(at: corruptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corruptData = Data("{\"cards\":false}".utf8)
        try corruptData.write(to: corruptURL)
        let corruptWallet = WalletStore(fileURL: corruptURL, dexes: [], ladder: [])
        try require(!corruptWallet.buyPacks(setID: "sv8pt5", count: 1, total: 1), "Unreadable save was writable")
        try require(try Data(contentsOf: corruptURL) == corruptData, "Unreadable original overwritten")
        var futureState = initial
        futureState.schemaVersion = 999
        let futureData = try JSONEncoder().encode(futureState)
        try futureData.write(to: url, options: .atomic)
        var refusedDowngrade = false
        do { _ = try persistence.load() }
        catch GamePersistence.Failure.newerVersion { refusedDowngrade = true }
        try require(refusedDowngrade && (try Data(contentsOf: url)) == futureData,
                    "Newer save was downgraded to an old backup")

        guard let cardURL = AppResources.bundle?.url(forResource: "card-prices", withExtension: "json"),
              let packURL = AppResources.bundle?.url(forResource: "pack-prices", withExtension: "json")
        else { throw Failure(description: "Missing price resources") }
        var envelope: [String: Any] = ["schemaVersion": 1,
            "cardPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: cardURL)),
            "packPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: packURL))]
        let priceData = try JSONSerialization.data(withJSONObject: envelope)
        let localPrices = PriceSnapshotStore(url: directory.appendingPathComponent("prices.json"))
        try localPrices.apply(priceData)
        try require(localPrices.usesImportedSnapshot, "Snapshot was not applied")
        var partialCards = envelope["cardPrices"] as! [String: Any]
        partialCards["printingPrices"] = [:] as [String: Double]
        envelope["cardPrices"] = partialCards
        var rejected = false
        do { try localPrices.apply(JSONSerialization.data(withJSONObject: envelope)) }
        catch { rejected = true }
        try require(rejected && (try Data(contentsOf: localPrices.url)) == priceData, "Partial snapshot replaced prices")
        partialCards["printingPrices"] = ["sv8pt5-1#invented": 42]
        envelope["cardPrices"] = partialCards
        rejected = false
        do { _ = try PriceSnapshotStore.validate(JSONSerialization.data(withJSONObject: envelope)) }
        catch { rejected = true }
        try require(rejected, "Unknown printing was accepted")
        try localPrices.reset()
        try require(!localPrices.usesImportedSnapshot && FileManager.default.fileExists(atPath: localPrices.url.appendingPathExtension("previous").path),
                    "Snapshot reset lost recovery copy")
        print("PASS Oripa rollback, real disk failure, unrecoverable-save protection, snapshot import/rejection/reset")

        var rng = PackSeedGenerator(seed: 20260923)
        var samples = 0
        for set in index.sets {
            let recipe = PackRecipe.forSet(set.id, era: index.era(set.id))
            let odds = PackOpening.packOdds(setID: set.id, index: index)  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
            try require(abs(odds.reduce(0) { $0 + $1.probability } - 1) < 0.000001, "Odds sum: \(set.id)")
            for _ in 0..<200 {
                var pity = PackConfig.pityThreshold
                let pack = PackOpening.draw(setID: set.id, index: index, alreadyOwned: [],
                    perks: .caps, pity: &pity, mode: .realistic, using: &rng)
                try require(pity == 0 && pack.cards.count == recipe.contents.gameCardCount, "Realistic count/pity: \(set.id)")
                try require(pack.cards.allSatisfy {
                    $0.isSupplementalEnergy || index.card($0.id)?.setID == set.id
                }, "Wrong-set card")
                if recipe.specialRules.isEmpty { try require(!pack.variant.isSpecialHit, "Impossible God Pack") }
                samples += 1
            }
        }
        var found: Set<PackVariant> = []
        for seed in 0..<100_000 {
            var rng = PackSeedGenerator(seed: UInt64(seed))
            var pity = 0
            let result = PackOpening.draw(setID: "sv8pt5", index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                                          pity: &pity, mode: .realistic, using: &rng)
            if result.variant == .prismaticEvolutionsDemigod {
                try require(result.cards.filter { $0.tier == .specialArtRare }.count == 3, "Demi composition")
                found.insert(result.variant)
            }
            if result.variant == .prismaticEvolutionsGod {
                try require(result.cards.first?.finish == .masterBall && result.cards.count == 10, "God composition")
                found.insert(result.variant)
            }
            if found.count == 2 { break }
        }
        try require(found.count == 2, "Missing special variant")
        do {
            var previewRNG = PackSeedGenerator(seed: 20260929)
            guard let ascended = PackOpening.godPackPreview(
                setID: "me2pt5", index: index, alreadyOwned: [], using: &previewRNG
            ) else { throw Failure(description: "Missing Ascended Heroes God Pack preview") }
            try require(ascended.variant == .ascendedHeroesGod
                        && ascended.cards.count == 10
                        && ascended.cards.filter { $0.tier == .megaAttack }.count == 3
                        && ascended.cards.filter { $0.tier == .specialArtRare }.count == 7
                        && Set(ascended.cards.map(\.id)).count == 10,
                        "Ascended Heroes God Pack composition")
        }
        if AppLinks.isCustomBuild {
            try require(!AppLinks.updatesConfigured, "Custom build allows upstream updates")
        } else {
            try require(AppLinks.updatesConfigured, "Stable build cannot check for updates")
            try require(AppLinks.updateChannel == "stable", "Official build uses a non-stable update channel")
        }
        print("PASS \(index.sets.count) sets / \(samples) realistic packs; Prismatic and Ascended special variants; update channel policy")
    }

    /// 등록된 모든 영문 세트가 코드·광고를 빼고 실제 플레이 카드 수만큼 표시되는지 확인한다.
    /// 별도 에너지는 이미지까지 디코딩해, 숫자만 늘고 빈 카드가 나오는 회귀도 막는다.
    private static func auditUnlimitedBulkSale(_ index: CardIndex) throws {
        guard let prices = CardPrices.shared,
              let expensive = index.cards.first(where: { prices.krw(MarketEconomy.usd(cardID: $0.id, prices: prices)) > 10_000 }),
              let cheap = index.cards.first(where: { prices.krw(MarketEconomy.usd(cardID: $0.id, prices: prices)) <= 1_000 }),
              let outside = index.cards.first(where: { $0.id != expensive.id && $0.id != cheap.id })
        else { throw Failure(description: "Missing bulk-sale fixtures") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-sale-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game-state.json")
        let wallet = WalletStore(fileURL: url, dexes: [], ladder: [])
        wallet.collect([cheap.id, cheap.id, cheap.id, expensive.id, expensive.id, expensive.id,
                        outside.id, outside.id])
        let pool = [cheap, expensive]
        let capped = WalletStore.bulkSaleTargets(pool, maxWon: 10_000,
            spares: { wallet.spareCount($0) }, prices: prices)
        try require(capped == [cheap.id], "Existing 10,000-won cap changed")
        // Unlimited selection must not depend on availability of exchange-rate/price data.
        let all = WalletStore.bulkSaleTargets(pool, maxWon: nil,
            spares: { wallet.spareCount($0) }, prices: nil)
        try require(all == pool.map(\.id), "Unlimited scope excluded expensive duplicates")
        let preview = wallet.bulkSalePreview(all)
        let sold = wallet.sellSpares(all)
        try require(preview == sold && sold.kinds == 2 && sold.copies == 4,
                    "Unlimited sale differed from confirmation preview")
        try require(wallet.cardCount(cheap.id) == 1 && wallet.cardCount(expensive.id) == 1
            && wallet.cardCount(outside.id) == 2, "Unlimited sale crossed filter or sold the last copy")
        let remaining = WalletStore.bulkSaleTargets(pool, maxWon: nil,
            spares: { wallet.spareCount($0) }, prices: prices)
        try require(remaining.isEmpty, "Unlimited scope selected single-copy cards")
        let restored = try GamePersistence(url: url).load().state
        try require(restored.cards == wallet.state.cards && restored.refundedTokens == sold.tokens,
                    "Unlimited sale did not persist exact cards/refund")
        print("PASS unlimited bulk sale: >10,000-won cards, capped-mode parity, preview/refund, keep-one, active-filter boundary, persistence")
    }

    static func auditPhysicalPackCards(_ index: CardIndex) throws {
        for style in SupplementalEnergyCard.Style.allCases {
            let types = style == .sunMoon
                ? SupplementalEnergyCard.EnergyType.allCases
                : SupplementalEnergyCard.EnergyType.allCases.filter { $0 != .fairy }
            for type in types {
                let id = "\(SupplementalEnergyCard.idPrefix)\(style.rawValue)-\(type.rawValue)"
                guard let data = SupplementalEnergyCard.data(cardID: id) else {
                    throw Failure(description: "Missing supplemental Energy art: \(id)")
                }
                try require(SupplementalEnergyCard.accepts(data),
                            "Low-resolution supplemental Energy art: \(id)")
            }
        }
        var checked = 0
        var energySets = 0
        for (offset, set) in index.sets.enumerated() {
            let era = index.era(set.id)
            let recipe = PackRecipe.forSet(set.id, era: era)
            var generator = PackSeedGenerator(seed: UInt64(offset + 1))
            var pity = 0
            let opened = PackOpening.draw(setID: set.id, index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                pity: &pity, mode: .realistic, using: &generator)
            try require(opened.cards.count == recipe.contents.gameCardCount,
                        "Expansion-card count mismatch: \(set.id)")
            let supplement = PackSupplement.contents(setID: set.id, era: era,
                variant: opened.variant, cards: opened.cards)
            let energy = SupplementalEnergyCard.cards(setID: set.id, era: era,
                supplement: supplement, expansionCards: opened.cards)
            try require(energy.count == supplement.energyCount,
                        "Supplemental Energy count mismatch: \(set.id)")
            for card in energy {
                if set.id == "cel30" || set.id.hasPrefix("me") {
                    let expected: SupplementalEnergyCard.Style = set.id == "cel30" ? .anniversary : .megaEvolution
                    try require(SupplementalEnergyCard.descriptor(cardID: card.id)?.style == expected,
                                "Wrong English MEE printing: \(set.id) -> \(card.id)")
                }
                guard let data = SupplementalEnergyCard.data(cardID: card.id) else {
                    throw Failure(description: "Missing supplemental Energy art: \(card.id)")
                }
                try require(SupplementalEnergyCard.accepts(data),
                            "Low-resolution supplemental Energy art: \(card.id)")
                try require(card.isSupplementalEnergy && !card.isNew && card.tier == .energy,
                            "Supplemental Energy leaked into collectible metadata: \(set.id)")
            }
            if recipe.contents.energyCardCount > 0 { energySets += 1 }
            checked += 1
        }
        let anniversary = PackSupplement.contents(setID: "cel30", era: .scarletViolet,
            variant: .standard, cards: [PulledCard(id: "cel30-1", tier: .common, isNew: false)])
        let celebrations = PackRecipe.forSet("cel25", era: .swordShield).contents
        try require(anniversary.energyCount == 1 && anniversary.holoEnergy,
                    "30th Celebration foil Energy missing")
        for (setID, style) in [("cel30", SupplementalEnergyCard.Style.anniversary), ("me1", .megaEvolution)] {
            var generator = PackSeedGenerator(seed: 123)
            let energy = SupplementalEnergyCard.randomCard(setID: setID, era: .scarletViolet,
                                                          finish: .normal, using: &generator)
            try require(SupplementalEnergyCard.descriptor(cardID: energy.id)?.style == style,
                        "Random Energy used the wrong MEE printing: \(setID)")
        }
        try require(celebrations.gameCardCount == 4 && celebrations.energyCardCount == 0,
                    "Celebrations must stay four cards without Energy")
        for (setID, expectedFinish) in PackRecipe.reverseSlotEnergyFinish {
            var generator = PackSeedGenerator(seed: 0xE11E_0000)
            var pity = 0
            var found = false
            for _ in 0..<200 {
                let opened = PackOpening.draw(setID: setID, index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                    pity: &pity, mode: .realistic, using: &generator)
                try require(opened.cards.count == PackRecipe.forSet(setID, era: index.era(setID)).contents.gameCardCount,
                            "Reverse Energy changed pack size: \(setID)")
                if opened.cards.contains(where: { $0.isSupplementalEnergy && $0.finish == expectedFinish }) {
                    found = true
                    break
                }
            }
            try require(found, "Reverse Holo Energy is unreachable: \(setID)")
        }
        print("PASS physical pack cards: \(checked) sets, \(energySets) Energy-era sets; code/ad excluded")
    }

    /// XCTest를 쓸 수 없는 CommandLineTools 환경에서도 성장 중인 대형 rollout의 이어 읽기 계약을 검증한다.
    private static func auditCodexIncrementalParsing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ppb-codex-incremental-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rollout.jsonl")
        let meta = #"{"type":"session_meta","timestamp":"2026-09-29T00:00:00Z","payload":{"id":"session-a"}}"#
        let first = #"{"timestamp":"2026-09-29T00:00:01Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":10,"total_tokens":110},"last_token_usage":{"input_tokens":100,"output_tokens":10,"total_tokens":110}}}}"#
        let second = #"{"timestamp":"2026-09-29T00:00:02Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":200,"output_tokens":20,"total_tokens":220},"last_token_usage":{"input_tokens":100,"output_tokens":10,"total_tokens":110}}}}"#
        let third = #"{"timestamp":"2026-09-29T00:00:03Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":310,"output_tokens":31,"total_tokens":341},"last_token_usage":{"input_tokens":110,"output_tokens":11,"total_tokens":121}}}}"#
        try "\(meta)\n\(first)".write(to: url, atomically: true, encoding: .utf8)
        let fmt = LocalUsageReader.localDayFormatter()
        let initial = LocalUsageReader.parseCodexRolloutIncrementally(url, fmt: fmt)
        try require(initial.succeeded && initial.rollout.events.count == 1,
                    "Cold Codex parse lost the final JSONL line")

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n\(second)".utf8))
        let appended = LocalUsageReader.parseCodexRolloutIncrementally(
            url, fmt: fmt, previous: initial.rollout, checkpoint: initial.checkpoint)
        try require(appended.succeeded && appended.startOffset == initial.checkpoint.offset
                    && appended.startOffset > 0,
                    "Codex append restarted from byte zero")
        try require(appended.rollout.events.map(\.entry.total) == [110, 110],
                    "Codex append changed existing usage")

        let split = third.index(third.startIndex, offsetBy: third.count / 2)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(("\n" + third[..<split]).utf8))
        let partial = LocalUsageReader.parseCodexRolloutIncrementally(
            url, fmt: fmt, previous: appended.rollout, checkpoint: appended.checkpoint)
        try require(partial.succeeded && partial.rollout.events.count == 2,
                    "Half-written Codex JSONL was accepted")
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(third[split...].utf8))
        let completed = LocalUsageReader.parseCodexRolloutIncrementally(
            url, fmt: fmt, previous: partial.rollout, checkpoint: partial.checkpoint)
        let cold = LocalUsageReader.parseCodexRollout(url, fmt: fmt)
        try require(completed.succeeded && completed.startOffset == partial.checkpoint.offset
                    && completed.startOffset > 0,
                    "Partial Codex line restarted from byte zero")
        try require(completed.rollout.events.map(\.entry.id) == cold.events.map(\.entry.id)
                    && completed.rollout.events.map(\.entry.total) == [110, 110, 121],
                    "Incremental Codex parse differs from a cold parse")
        print("PASS Codex JSONL append cursor, partial-line recovery, cold-parse parity")
    }

    private static func auditDexCardSearch(_ index: CardIndex) throws {
        guard let pikachu = index.cards.first(where: { $0.name.localizedCaseInsensitiveContains("Pikachu") }),
              let koreanName = pikachu.nameKo,
              let setDex = DexIndex.loadBundled().setDexes.first(where: { $0.homeSet == pikachu.setID })
        else { throw Failure(description: "Missing Pikachu/search fixture") }

        try require(DexCardSearch.normalized(" PIKÁ-CHU ") == "pikachu",
                    "Dex search normalization lost case/diacritic/punctuation folding")
        try require(DexCardSearch.containsCard(named: "pikachu", in: setDex, index: index),
                    "English card name cannot find its set dex")
        try require(DexCardSearch.containsCard(named: koreanName, in: setDex, index: index),
                    "Korean card name cannot find its set dex")
        try require(!DexCardSearch.containsCard(named: "definitely-not-a-card", in: setDex, index: index),
                    "Unknown card name matched a dex")
        print("PASS dex card-name search: Korean/English, folded punctuation, empty result")
    }
}
