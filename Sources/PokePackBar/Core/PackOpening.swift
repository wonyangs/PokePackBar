import Foundation

/// 팩 구성과 확률. 값을 바꾸면 게임 밸런스가 바뀐다.
enum PackConfig {
    static let cardsPerPack = 10

    /// 슬롯 구성 — 실제 카드 게임의 팩(커먼 다수 + 언커먼 + 히트 1장)을 따른다.
    /// 에너지가 있는 세트는 필러 1칸이 에너지로 바뀐다.
    static let commonSlots = 4
    static let uncommonSlots = 3
    static let fillerSlots = 2      // 커먼/언커먼 중에서
    static let hitSlots = 1

    /// 히트 슬롯의 계층 가중치. 카드 실제 보유 수와 무관하게 게임 확률로 정한다 —
    /// 어떤 세트는 시크릿이 37장이고 어떤 세트는 0장이라, 보유 수를 그대로 쓰면
    /// 세트마다 체감 확률이 뒤집힌다.
    static let hitWeights: [(tier: CardTier, weight: Int)] = [
        (.rare, 55), (.doubleRare, 25), (.artRare, 7), (.tripleRare, 6),
        (.superRare, 4), (.specialArtRare, 2), (.ultraRare, 1),
    ]

    /// 특별 세트의 팩 장수. common 계층이 없는 세트를 말한다.
    ///
    /// 25장짜리 기념 세트처럼 전부 rare 이상으로 구성된 세트가 있다. 여기에 일반 팩 구성
    /// (커먼 4·언커먼 3·필러 2)을 적용하면 폴백이 아홉 슬롯을 전부 rare 로 채운다.
    /// 팩 하나가 세트의 40% 를 쏟아내고, 모든 카드가 같은 계층이라 히트 슬롯도 의미가 없어진다.
    /// 실제 카드 게임에서도 이런 세트의 팩은 4장이다.
    static let specialPackSize = 4

    /// 특별 세트의 계층 가중치. 전 슬롯을 이 가중치로 뽑아 팩 안에 등급 차이를 만든다.
    static let specialWeights: [(tier: CardTier, weight: Int)] = [
        (.rare, 46), (.doubleRare, 30), (.artRare, 8), (.tripleRare, 7),
        (.superRare, 5), (.specialArtRare, 3), (.ultraRare, 1),
    ]
}

/// 팩 가격. 세트마다 표를 두지 않고 구성에서 유도한다 — 세트를 추가할 때 가격을 잊지 않게.
enum PackPricing {
    /// 일반 팩(10장).
    static let standard = 10_000_000

    /// 특별 팩(4장) — 전 카드가 레어 이상이라 장수가 적어도 값이 높다.
    static let special = 20_000_000

    static func price(setID: String, index: CardIndex) -> Int {
        let pool = index.pools[setID] ?? [:]
        return (pool[.common] ?? []).isEmpty ? special : standard
    }

    static func cardCount(setID: String, index: CardIndex) -> Int {
        let pool = index.pools[setID] ?? [:]
        return (pool[.common] ?? []).isEmpty ? PackConfig.specialPackSize : PackConfig.cardsPerPack
    }
}

/// 팩 개봉 결과 카드 1장.
struct PulledCard: Equatable, Sendable, Identifiable {
    let id: String        // 카드 ID
    let tier: CardTier
    /// 이 개봉으로 처음 얻은 카드인가. 연출에서 신규 표시에 쓴다.
    let isNew: Bool
}

/// 팩 개봉 — 순수 로직.
///
/// 난수 생성기를 주입받는다. 그래야 확률 분포를 고정된 입력으로 검증할 수 있다.
/// 보유량 변경과 화면 표시는 호출부가 맡는다.
enum PackOpening {

    /// 팩 1개를 뽑는다. 세트에 카드가 없으면 빈 배열.
    ///
    /// - Parameters:
    ///   - alreadyOwned: 신규 여부 판정에 쓸 기존 보유 카드 ID.
    static func draw(
        setID: String,
        index: CardIndex,
        alreadyOwned: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> [PulledCard] {
        guard let pool = index.pools[setID], !pool.isEmpty else { return [] }

        // common 이 없는 세트는 일반 팩 구성을 쓸 수 없다. 전 슬롯을 가중 추첨한다.
        if (pool[.common] ?? []).isEmpty {
            var picked: [PulledCard] = []
            var used: Set<String> = []
            for _ in 0..<PackConfig.specialPackSize {
                let tier = weightedTier(PackConfig.specialWeights, available: pool, using: &generator)
                guard let id = pick(tier: tier, from: pool, avoiding: used, using: &generator) else { continue }
                used.insert(id)
                picked.append(PulledCard(id: id, tier: index.card(id)?.tier ?? tier,
                                         isNew: !alreadyOwned.contains(id)))
            }
            return picked
        }

        var requests: [CardTier] = []
        requests.append(contentsOf: Array(repeating: .common, count: PackConfig.commonSlots))
        requests.append(contentsOf: Array(repeating: .uncommon, count: PackConfig.uncommonSlots))

        // 에너지가 있는 세트는 필러 한 칸을 에너지로 준다. 나머지 필러는 커먼이다.
        let hasEnergy = !(pool[.energy] ?? []).isEmpty
        for slot in 0..<PackConfig.fillerSlots {
            requests.append(hasEnergy && slot == 0 ? .energy : .common)
        }

        for _ in 0..<PackConfig.hitSlots {
            requests.append(hitTier(available: pool, using: &generator))
        }

        var picked: [PulledCard] = []
        var usedInThisPack: Set<String> = []
        for tier in requests {
            guard let id = pick(tier: tier, from: pool, avoiding: usedInThisPack, using: &generator) else { continue }
            usedInThisPack.insert(id)
            let actualTier = index.card(id)?.tier ?? tier
            picked.append(PulledCard(id: id, tier: actualTier, isNew: !alreadyOwned.contains(id)))
        }
        return picked
    }

    /// 개봉에서 보여줄 순서 — 등급 오름차순. 가장 희귀한 카드가 마지막에 나온다.
    /// 같은 등급 안에서는 뽑힌 순서를 유지한다.
    static func revealOrder(_ cards: [PulledCard]) -> [PulledCard] {
        cards.enumerated()
            .sorted { ($0.element.tier.rank, $0.offset) < ($1.element.tier.rank, $1.offset) }
            .map(\.element)
    }

    /// 히트 슬롯의 계층을 가중 추첨한다. 그 세트에 없는 계층은 후보에서 빼고 가중치를 다시 정규화한다.
    /// 빼지 않으면 1999년 세트에서 시크릿을 뽑았다고 판정하고 폴백으로 흘러가 확률이 왜곡된다.
    static func hitTier(
        available pool: [CardTier: [String]],
        using generator: inout some RandomNumberGenerator
    ) -> CardTier {
        weightedTier(PackConfig.hitWeights, available: pool, using: &generator)
    }

    /// 가중치 목록에서 계층을 추첨한다. 그 세트에 없는 계층은 후보에서 빼고 가중치를 다시 정규화한다.
    /// 빼지 않으면 1999년 세트에서 시크릿을 뽑았다고 판정하고 폴백으로 흘러가 확률이 왜곡된다.
    static func weightedTier(
        _ weights: [(tier: CardTier, weight: Int)],
        available pool: [CardTier: [String]],
        using generator: inout some RandomNumberGenerator
    ) -> CardTier {
        let candidates = weights.filter { !(pool[$0.tier] ?? []).isEmpty }
        guard !candidates.isEmpty else { return .rare }   // 폴백 체인이 처리한다
        let total = candidates.reduce(0) { $0 + $1.weight }
        var roll = Int(generator.next(upperBound: UInt64(total)))
        for c in candidates {
            roll -= c.weight
            if roll < 0 { return c.tier }
        }
        return candidates[candidates.count - 1].tier
    }

    /// 요청한 계층에서 카드 하나를 고른다. 그 계층이 비어 있으면 폴백 체인을 따라간다.
    ///
    /// 같은 팩 안에서는 중복을 피한다. 다만 풀이 작으면 피할 수 없으므로,
    /// 후보를 다 소진하면 중복을 허용한다 — 슬롯을 비우는 것보다 낫다.
    static func pick(
        tier: CardTier,
        from pool: [CardTier: [String]],
        avoiding used: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> String? {
        for candidate in tier.fallbackChain {
            let ids = pool[candidate] ?? []
            guard !ids.isEmpty else { continue }
            let fresh = ids.filter { !used.contains($0) }
            let source = fresh.isEmpty ? ids : fresh
            return source[Int(generator.next(upperBound: UInt64(source.count)))]
        }
        return nil
    }
}
