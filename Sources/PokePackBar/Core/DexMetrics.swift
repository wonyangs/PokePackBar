import Foundation

/// `--dex-metrics`: 번들 도감의 난이도를 지금 팩 구성과 시세로 다시 잰다.
///
/// `dex.json` 의 숫자(필요 팩, 완성 비용, 카드값, 별)는 생성 시점의 확률과 시세로 굳은 값이라
/// 팩 표나 시세가 바뀌면 조용히 거짓이 된다. 앱이 쓰는 바로 그 식(`DexDifficulty`)으로 다시
/// 재서 JSON 으로 내보내고, `scripts/rebuild_dex.py` 가 이것으로 `dex.json` 을 고친다.
/// 계산을 파이썬에 다시 적으면 둘이 갈라진다.
enum DexMetrics {
    struct Milestone: Encodable {
        let need: Int
        let medianPacks: Int
        let medianTokens: Int
    }

    struct Row: Encodable {
        let id: String
        let medianPacks: Int
        let hardPacks: Int
        let medianTokens: Int
        let valueUSD: Double
        let tier: Int
        let milestones: [Milestone]
    }

    struct Output: Encodable {
        let packPrices: [String: Int]
        let species: [String: Int]
        let dexes: [Row]
    }

    static func run() throws {
        guard let index = CardIndex.shared, let prices = CardPrices.shared else {
            throw LocalAudit.Failure(description: "Missing card index or prices")
        }
        let dexes = DexIndex.loadBundled().dexes
        var packPrices: [String: Int] = [:]
        var species: [String: Int] = [:]
        for set in index.sets where index.pools[set.id] != nil {
            // 도감 난이도는 혜택 없는 기본 팩값으로 잰다(DexDifficulty.tokensNeeded 와 같다).
            packPrices[set.id] = PackPricing.price(setID: set.id, index: index)   // 혜택 제외
            species[set.id] = index.cards(inSet: set.id).count
        }
        let rows = dexes.map { dex -> Row in
            let value = DexProgress.recomputedValue(of: dex, prices: prices, index: index)
            if dex.kind == .set {
                let price = packPrices[dex.homeSet] ?? 0
                let milestones = dex.milestones.map { milestone -> Milestone in
                    let packs = DexDifficulty.packsForDistinct(setID: dex.homeSet, need: milestone.need,
                                                               index: index)
                    return Milestone(need: milestone.need, medianPacks: packs, medianTokens: packs * price)
                }
                let last = milestones.last
                return Row(id: dex.id, medianPacks: last?.medianPacks ?? 0, hardPacks: last?.medianPacks ?? 0,
                           medianTokens: last?.medianTokens ?? 0, valueUSD: value,
                           tier: DexDifficulty.tier(forValueUSD: value), milestones: milestones)
            }
            return Row(id: dex.id,
                       medianPacks: DexDifficulty.packsNeeded(for: dex, quantile: 0.5, index: index),
                       hardPacks: DexDifficulty.packsNeeded(for: dex, quantile: 0.9, index: index),
                       medianTokens: DexDifficulty.tokensNeeded(cards: dex.cards, quantile: 0.5,
                                                                index: index, prices: prices),
                       valueUSD: value, tier: DexDifficulty.tier(forValueUSD: value), milestones: [])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Output(packPrices: packPrices, species: species, dexes: rows))
        FileHandle.standardOutput.write(data)
    }
}
