import Foundation

/// 도감 하나의 진행 상황. 순수 값이라 화면 없이 검증할 수 있다.
struct DexStatus: Sendable, Equatable, Identifiable {
    let dex: Dex
    /// 갖고 있는 구성원 수.
    let ownedCount: Int
    /// 아직 없는 구성원. 순서는 도감 정의 순서를 따른다.
    let missing: [String]
    /// 보상을 이미 수령했는가. 수령한 도감만 혜택을 준다.
    ///
    /// 지금 보유 상태와 따로 둔다. 수령은 영구 기록이라, 나중에 도감에 카드가 추가돼
    /// 구성이 바뀌어도 이미 받은 혜택을 회수하지 않는다.
    let claimed: Bool

    var id: String { dex.id }

    var total: Int { dex.cards.count }

    /// 지금 보유분만으로 완성 조건을 만족하는가.
    var isFilled: Bool { missing.isEmpty }

    /// 화면에서 완성으로 취급하는가.
    var isComplete: Bool { claimed || isFilled }

    /// 다 모았는데 아직 보상을 안 받은 상태. 목록 맨 위로 올린다.
    var isClaimable: Bool { isFilled && !claimed }

    var fraction: Double { total > 0 ? Double(ownedCount) / Double(total) : 0 }
}

enum DexProgress {

    static func status(for dex: Dex, owned: (String) -> Bool, claimed: Bool) -> DexStatus {
        let missing = dex.cards.filter { !owned($0) }
        return DexStatus(dex: dex, ownedCount: dex.cards.count - missing.count,
                         missing: missing, claimed: claimed)
    }

    static func statuses(dexes: [Dex], owned: (String) -> Bool,
                         claimed: Set<String>) -> [DexStatus] {
        dexes.map { status(for: $0, owned: owned, claimed: claimed.contains($0.id)) }
    }

    /// 표시 순서.
    ///
    /// 받을 보상이 있는 것을 맨 위로 올린다. 그 다음은 완성에 가까운 순서다 —
    /// 다음에 무엇을 노려야 하는지가 위에서부터 읽혀야 한다. 수령까지 끝난 것은 맨 아래.
    static func sorted(_ statuses: [DexStatus]) -> [DexStatus] {
        statuses.sorted { a, b in
            if a.isClaimable != b.isClaimable { return a.isClaimable }
            if a.claimed != b.claimed { return b.claimed }
            if a.missing.count != b.missing.count { return a.missing.count < b.missing.count }
            if a.dex.tier != b.dex.tier { return a.dex.tier < b.dex.tier }
            return a.dex.id < b.dex.id
        }
    }

    /// 이번 보유 상태에서 새로 다 모인 도감.
    ///
    /// 개봉 직후에 호출해 개봉 화면에서 알린다. 보상은 여기서 주지 않는다 —
    /// 수령은 사용자가 도감에서 직접 누른다.
    static func newlyFilled(dexes: [Dex], owned: (String) -> Bool,
                            claimed: Set<String>, before: Set<String>) -> [Dex] {
        dexes.filter { dex in
            guard !claimed.contains(dex.id) else { return false }
            guard dex.cards.allSatisfy(owned) else { return false }
            // 이번 개봉으로 채워진 것만. 원래 다 모여 있던 것을 매번 다시 알리면 소음이 된다.
            return !dex.cards.allSatisfy(before.contains)
        }
        // 어려운 것을 먼저 알린다. 쉬운 것 여러 개에 묻히면 안 된다.
        .sorted { $0.tier != $1.tier ? $0.tier > $1.tier : $0.id < $1.id }
    }
}

/// 도감 난이도를 실제 팩 확률에서 계산한다.
///
/// `dex.json` 의 `tier`·`medianPacks` 는 생성 스크립트가 계산해 넣은 값이다. 팩 구성이나
/// 세트 구성이 바뀌면 그 값이 조용히 거짓이 되므로, 앱이 같은 식으로 다시 계산해 두고
/// 테스트가 대조한다. 확률표와 같은 출처(`PackOpening.packOdds`)를 쓰는 것이 핵심이다.
enum DexDifficulty {

    /// 난이도 경계 — 완성까지 필요한 팩 수(50% 지점)의 상한.
    /// `scripts/build_dex.py` 의 `TIER_LIMITS` 와 같아야 한다.
    static let tierLimits = [15, 50, 150, 350]

    /// 티어별 지급 팩. 같은 스크립트의 `REWARD_PACKS` 와 같아야 한다.
    static let rewardPacks = [1, 3, 8, 20, 50]

    static func tier(forMedianPacks packs: Int) -> Int {
        for (offset, limit) in tierLimits.enumerated() where packs <= limit { return offset + 1 }
        return tierLimits.count + 1
    }

    /// 카드 한 장이 팩 하나에서 나올 확률.
    ///
    /// 등급별 기대 장수를 그 등급의 카드 종류 수로 나눈다. 기대 장수는 확률표에서 되돌린다 —
    /// 확률표는 카드 한 장 기준으로 정규화돼 있으므로 팩 장수를 곱하면 기대 장수가 된다.
    static func pullProbability(cardID: String, index: CardIndex,
                                perks: DexPerks = .none) -> Double {
        guard let entry = index.card(cardID) else { return 0 }
        let siblings = index.pools[entry.setID]?[entry.tier]?.count ?? 0
        guard siblings > 0 else { return 0 }
        let odds = PackOpening.packOdds(setID: entry.setID, index: index, perks: perks)
        guard let match = odds.first(where: { $0.tier == entry.tier }) else { return 0 }
        let perPack = Double(PackPricing.cardCount(setID: entry.setID, index: index, perks: perks))
        return match.probability * perPack / Double(siblings)
    }

    /// 구성원을 모두 모으는 데 필요한 팩 수.
    ///
    /// 세트마다 따로 사야 하므로 세트별로 구해 더한다. 한 세트 안에서는 카드마다 독립이라
    /// n 팩 뒤에 전부 모였을 확률이 곱이 되고, 그 값이 `quantile` 을 넘는 최소 n 을 찾는다.
    static func packsNeeded(cards: [String], quantile: Double, index: CardIndex,
                            perks: DexPerks = .none) -> Int {
        var bySet: [String: [Double]] = [:]
        for card in cards {
            guard let entry = index.card(card) else { return 0 }
            let p = pullProbability(cardID: card, index: index, perks: perks)
            guard p > 0 else { return 0 }
            bySet[entry.setID, default: []].append(p)
        }

        var total = 0
        for probabilities in bySet.values {
            var packs = 0
            while packs < 100_000 {
                packs += 1
                let chance = probabilities.reduce(1.0) { $0 * (1 - pow(1 - $1, Double(packs))) }
                if chance >= quantile { break }
            }
            total += packs
        }
        return total
    }
}
