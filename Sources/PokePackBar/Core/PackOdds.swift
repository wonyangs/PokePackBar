import Foundation

/// 세트별 실측 봉입률. `Resources/pack-odds.json` 이 단일 출처다.
///
/// 시대 표(`PackConfig`)는 그 시대의 평균 구조다. 실물은 같은 시대 안에서도 세트마다 다르다 —
/// Paradox Rift 이후 SV 의 스페셜아트레어는 1/32 가 아니라 1/80~1/100 이고, Prism Star 는
/// 레어 칸이 아니라 역홀로 칸에서 1/8~1/18 로 나온다. 세트마다 잰 값을 데이터 한 곳에 두고,
/// 없는 세트만 시대 표로 떨어진다.
///
/// 한 세트는 세 가지를 바꿀 수 있다.
/// - `slots`: 칸 종류별 등급 가중치(만분율). 있으면 그 칸의 시대 표를 통째로 대신한다.
/// - `pools`: 칸과 등급별로 뽑을 수 있는 카드를 rarity 나 카드 ID 로 좁힌다. 같은 등급 안에서도
///   실물 위치가 다른 카드(예: HGSS 의 Prime 은 역홀로 칸, 일반 홀로는 레어 칸)를 가른다.
/// - `finishes`: 칸과 등급별 판형 힌트. DP 역홀로 칸의 홀로레어는 역홀로 판으로 나온다.
///
/// 값을 바꾸면 서버 규칙 버전이 함께 바뀐다(`digest`). 앱과 서버가 같은 표로 뽑아야 하기 때문이다.
enum PackOdds {
    struct Filter: Decodable, Equatable, Sendable {
        let rarities: [String]?
        let ids: [String]?

        func matches(id: String, rarity: String?) -> Bool {
            if let ids, ids.contains(id) { return true }
            if let rarities, let rarity, rarities.contains(rarity) { return true }
            return false
        }
    }

    struct PoolRule: Decodable, Equatable, Sendable {
        let only: Filter?
        let exclude: Filter?

        func allows(id: String, rarity: String?) -> Bool {
            if let only, !only.matches(id: id, rarity: rarity) { return false }
            if let exclude, exclude.matches(id: id, rarity: rarity) { return false }
            return true
        }
    }

    struct Weight: Decodable, Equatable, Sendable {
        let tier: CardTier
        let weight: Int

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            tier = try container.decode(CardTier.self)
            weight = try container.decode(Int.self)
        }
    }

    struct SetOdds: Decodable, Sendable {
        let slots: [String: [Weight]]
        let pools: [String: [String: PoolRule]]?
        let finishes: [String: [String: String]]?
    }

    struct File: Decodable, Sendable {
        let version: String
        let sets: [String: SetOdds]
    }

    /// 번들 원본 바이트. 규칙 버전 다이제스트에 그대로 들어간다.
    static let data: Data? = AppResources.bundle?
        .url(forResource: "pack-odds", withExtension: "json")
        .flatMap { try? Data(contentsOf: $0) }

    static let file: File? = data.flatMap { try? JSONDecoder().decode(File.self, from: $0) }

    static var digest: String {
        data.map(OpeningRules.digest) ?? "unavailable"
    }

    static func weights(setID: String, slot: PackSlotKind) -> [(tier: CardTier, weight: Int)]? {
        file?.sets[setID]?.slots[slot.rawValue]?.map { (tier: $0.tier, weight: $0.weight) }
    }

    static func poolRules(setID: String, slot: PackSlotKind) -> [CardTier: PoolRule]? {
        guard let rules = file?.sets[setID]?.pools?[slot.rawValue], !rules.isEmpty else { return nil }
        var out: [CardTier: PoolRule] = [:]
        for (tier, rule) in rules {
            if let tier = CardTier(rawValue: tier) { out[tier] = rule }
        }
        return out
    }

    static func finishHint(setID: String, slot: PackSlotKind, tier: CardTier) -> PackFinishHint? {
        file?.sets[setID]?.finishes?[slot.rawValue]?[tier.rawValue].flatMap(PackFinishHint.init(rawValue:))
    }

    /// 칸과 등급 규칙으로 좁힌 풀. 규칙이 없는 등급은 그대로 둔다.
    static func restrict(_ pool: [CardTier: [String]], setID: String, slot: PackSlotKind,
                         index: CardIndex?) -> [CardTier: [String]] {
        guard let rules = poolRules(setID: setID, slot: slot) else { return pool }
        var restricted = pool
        for (tier, rule) in rules {
            restricted[tier] = (pool[tier] ?? []).filter {
                rule.allows(id: $0, rarity: index?.card($0)?.rarity)
            }
        }
        return restricted
    }

    /// 데이터가 앱이 아는 세트, 칸, 등급, 판형만 쓰는지, 칸마다 합이 100% 인지 확인한다.
    static func verify(index: CardIndex) throws {
        guard let file else { throw LocalAudit.Failure(description: "pack-odds.json 을 읽지 못했다") }
        let setIDs = Set(index.sets.map(\.id))
        for (setID, odds) in file.sets {
            guard setIDs.contains(setID) else {
                throw LocalAudit.Failure(description: "pack-odds: 모르는 세트 \(setID)")
            }
            let kinds = Set(PackRecipe.forSet(setID, era: index.era(setID)).slots.map(\.kind.rawValue))
            let pool = index.pools[setID] ?? [:]
            for (kind, weights) in odds.slots {
                guard kinds.contains(kind) else {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID) 에 없는 칸 \(kind)")
                }
                guard weights.reduce(0, { $0 + $1.weight }) == 10_000,
                      weights.allSatisfy({ $0.weight > 0 }),
                      Set(weights.map(\.tier)).count == weights.count else {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID)/\(kind) 가중치가 만분율이 아니다")
                }
                guard let slot = PackSlotKind(rawValue: kind) else { continue }
                let slotPool = PackOpening.slotPool(setID: setID, slot: slot, pool: pool, index: index)
                for entry in weights where (slotPool[entry.tier] ?? []).isEmpty {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID)/\(kind)/\(entry.tier.rawValue) 에 뽑을 카드가 없다")
                }
            }
            for (kind, rules) in odds.pools ?? [:] {
                guard kinds.contains(kind) else {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID) 풀 규칙의 칸 \(kind) 이 없다")
                }
                for tier in rules.keys where CardTier(rawValue: tier) == nil {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID)/\(kind) 의 모르는 등급 \(tier)")
                }
            }
            for (kind, hints) in odds.finishes ?? [:] {
                for (tier, hint) in hints where CardTier(rawValue: tier) == nil
                    || PackFinishHint(rawValue: hint) == nil || !kinds.contains(kind) {
                    throw LocalAudit.Failure(description: "pack-odds: \(setID)/\(kind)/\(tier) 판형 \(hint)")
                }
            }
        }
    }
}
