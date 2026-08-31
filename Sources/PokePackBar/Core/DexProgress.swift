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

    /// 도감이 담고 있는 카드값의 합(달러). 난이도와 정렬의 기준이다.
    ///
    /// `dex.json` 에 든 값을 그대로 쓴다. 화면이 열릴 때마다 수백 장을 더할 이유가 없고,
    /// 저장된 값이 시세와 어긋나지 않는지는 테스트가 대조한다.
    static func value(of dex: Dex, prices: CardPrices? = CardPrices.shared) -> Double {
        dex.valueUSD
    }

    /// 시세에서 다시 계산한 값. 저장된 값과 대조할 때 쓴다.
    static func recomputedValue(of dex: Dex, prices: CardPrices?) -> Double {
        dex.cards.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1, prices: prices) }
    }

    /// 표시 순서 — 어려운 것부터. 같은 난이도면 **값비싼 카드가 든 것**이 먼저다.
    ///
    /// 목표가 되는 조합이 위에 있어야 한다. 예전에는 카드 수가 적은 것을 앞에 뒀는데,
    /// 카드마다 값이 다른 지금은 장수가 목표의 무게를 말해 주지 않는다 — 두 장짜리가
    /// 열여섯 장짜리보다 값진 경우가 흔하다.
    ///
    /// 진행 상태로는 정렬하지 않는다. 카드를 얻을 때마다 목록이 재배열되면 어제 보던
    /// 도감이 어디 갔는지 매번 다시 찾아야 한다. 받을 보상이 있는 도감은 자리를 옮기는
    /// 대신 테두리와 수령 버튼으로 드러낸다.
    static func sorted(_ statuses: [DexStatus],
                       prices: CardPrices? = CardPrices.shared) -> [DexStatus] {
        let values = Dictionary(uniqueKeysWithValues:
            statuses.map { ($0.dex.id, value(of: $0.dex, prices: prices)) })
        return statuses.sorted { a, b in
            if a.dex.tier != b.dex.tier { return a.dex.tier > b.dex.tier }
            let left = values[a.dex.id] ?? 0, right = values[b.dex.id] ?? 0
            if left != right { return left > right }
            if a.total != b.total { return a.total < b.total }
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
/// `dex.json` 의 `tier`·`medianTokens` 는 생성 스크립트가 계산해 넣은 값이다. 팩 구성이나
/// 세트 구성이 바뀌면 그 값이 조용히 거짓이 되므로, 앱이 같은 식으로 다시 계산해 두고
/// 테스트가 대조한다. 확률표와 같은 출처(`PackOpening.packOdds`)를 쓰는 것이 핵심이다.
enum DexDifficulty {

    /// 난이도 경계 — 도감에 든 **카드값의 합**(달러)의 상한.
    /// `scripts/build_dex.py` 의 `TIER_LIMITS` 와 같아야 한다.
    ///
    /// 대략 2천원 · 1만 6천원 · 14만원 · 83만원 어치다. 달러로 두는 이유는 환율이
    /// 배포마다 조금씩 바뀌기 때문이다 — 원으로 두면 환율이 흔들릴 때 별이 따라 흔들린다.
    ///
    /// 팩 수로 재던 시절에는 세트별 팩값 차이가 반영되지 않았고, 완성 비용으로 재던 때는
    /// 그 값이 뽑기 확률에 묻혀 "무엇이 들어 있는가" 가 보이지 않았다. 카드값의 합은
    /// 화면에 그대로 보여 줄 수 있는 숫자이기도 하다.
    static let tierLimits = [1.5, 12.0, 100.0, 600.0]

    /// 도감을 완성할 때 들인 값의 몇 배를 돌려주는가. `build_dex.py` 의 `TARGET_RETURN`.
    ///
    /// 지급 팩 수를 티어표(1/3/8/20/50)로 적던 것을 버렸다. 완성에 필요한 팩이 9개에서
    /// 585개까지 65배 갈리고 세트별 팩값이 47배 갈리는데 팩 수는 티어로만 정해져서, 팩만의
    /// 리턴이 0.01배에서 1.61배까지 흩어져 있었다 — 어떤 도감은 31팩 들여 50팩을 받았다.
    /// 이제 스크립트가 이 비율에 맞춰 도감마다 팩 수를 계산해 넣는다.
    static let targetReturn = 0.30

    /// 지급 팩 수의 상한. `build_dex.py` 의 `MAX_REWARD_PACKS`.
    ///
    /// 팩은 **부수적인 재미**다. 값을 맞추려고 100개씩 주면 한 장씩 뜯는 것이 일이 된다.
    /// 보상의 본체는 영구 패시브이고, 팩은 곁들이는 것으로 둔다.
    static let maxRewardPacks = 10

    static func tier(forValueUSD value: Double) -> Int {
        for (offset, limit) in tierLimits.enumerated() where value <= limit { return offset + 1 }
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

        return packsBySet(bySet, quantile: quantile).values.reduce(0, +)
    }

    /// 완성에 드는 토큰. 세트마다 팩값이 다르므로 팩 수만으로는 난이도를 잴 수 없다 —
    /// 네오 제네시스 50팩과 샤이닝 페이츠 50팩은 45배 차이 나는 목표다.
    static func tokensNeeded(cards: [String], quantile: Double, index: CardIndex,
                             prices: CardPrices? = CardPrices.shared,
                             perks: DexPerks = .none) -> Int {
        var bySet: [String: [Double]] = [:]
        for card in cards {
            guard let entry = index.card(card) else { return 0 }
            let p = pullProbability(cardID: card, index: index, perks: perks)
            guard p > 0 else { return 0 }
            bySet[entry.setID, default: []].append(p)
        }
        return packsBySet(bySet, quantile: quantile).reduce(0) { running, entry in
            running + entry.value * PackPricing.price(setID: entry.key, index: index,
                                                      prices: prices, perks: perks)
        }
    }

    /// 세트마다 필요한 팩 수. 한 세트 안에서는 카드마다 독립이라 n 팩 뒤에 전부 모였을
    /// 확률이 곱이 되고, 그 값이 `quantile` 을 넘는 최소 n 을 찾는다.
    private static func packsBySet(_ bySet: [String: [Double]],
                                   quantile: Double) -> [String: Int] {
        var out: [String: Int] = [:]
        for (setID, probabilities) in bySet {
            var packs = 0
            while packs < 100_000 {
                packs += 1
                let chance = probabilities.reduce(1.0) { $0 * (1 - pow(1 - $1, Double(packs))) }
                if chance >= quantile { break }
            }
            out[setID] = packs
        }
        return out
    }
}
