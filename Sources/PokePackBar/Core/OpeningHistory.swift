import Foundation
import CryptoKit

enum OpeningMode: String, Codable, CaseIterable, Sendable {
    case game, realistic
}

/// SplitMix64, versioned together with the draw rules. No live wallet is needed.
struct PackSeedGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum OpeningRules {
    static let version = "english-2026-10-08-v6-measured-pull-rates"
    static let historyLimit = 1_000
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static let catalogueDigest: String = {
        guard let url = AppResources.bundle?.url(forResource: "card-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return "unavailable" }
        return digest(data)
    }()
}

struct PackSupplement: Codable, Equatable, Sendable {
    let energyCount: Int
    let holoEnergy: Bool
    let codeCount: Int

    static func contents(setID: String, era: PackEra, variant: PackVariant,
                         cards: [PulledCard] = []) -> Self {
        let counts = PackRecipe.forSet(setID, era: era).contents
        // Brilliant Stars부터 Crown Zenith까지 에너지 자리는 VSTAR 마커로 바뀔 수 있다.
        // 마커는 플레이 카드가 아니므로 화면에는 생략하되, 그 팩에 없던 에너지를 만들지는 않는다.
        // 제조사가 비율을 공개하지 않아 커뮤니티 개봉에서 흔히 관측되는 1/4을 시뮬레이터 값으로 쓴다.
        let vstarMarker = Self.vstarMarkerSets.contains(setID)
            && !cards.isEmpty
            && SupplementalEnergyCard.stableIndex(setID: "vstar-\(setID)", cards: cards,
                                                   upperBound: 4) == 0
        return Self(energyCount: vstarMarker ? 0 : counts.energyCardCount,
                    holoEnergy: setID == "cel30" || variant == .blackBoltWhiteFlareGod,
                    codeCount: counts.codeCardCount)
    }

    static let vstarMarkerSets: Set<String> = [
        "swsh9", "swsh9tg", "swsh10", "swsh10tg", "pgo", "swsh11", "swsh11tg",
        "swsh12", "swsh12tg", "swsh12pt5", "swsh12pt5gg",
    ]
}

struct OpeningRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let openedAt: Date
    let setID: String
    let seed: String
    let rulesVersion: String
    let catalogueDigest: String
    let mode: OpeningMode
    let hitOddsBonus: Double
    let pityBefore: Int
    let pityAfter: Int
    let variant: PackVariant
    let printings: [CardPrintingKey]
    let supplement: PackSupplement
    let cardPriceDate: String?
    let printingPriceDate: String?
    let priceSnapshotDigest: String?
    let packQuote: PackPriceQuote
}
