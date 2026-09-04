import Foundation

/// 도감 하나의 진행 상황. 순수 값이라 화면 없이 검증할 수 있다.
struct DexStatus: Sendable, Equatable, Identifiable {
    let dex: Dex
    /// 갖고 있는 구성원 수. 세트 도감은 그 세트에서 가진 **종** 수다.
    let ownedCount: Int
    /// 아직 없는 구성원. 순서는 도감 정의 순서를 따른다.
    ///
    /// **세트 도감은 비운다.** 284장을 늘어놓을 화면이 없고, 목표가 「전부」가 아니라
    /// 「몇 할」이라 빠진 목록이 뜻을 갖지 않는다.
    let missing: [String]
    /// 대상이 되는 종 수. 테마는 구성원 수, 세트는 그 세트의 종 수다.
    let total: Int
    /// 수령한 마일스톤 번호. 테마 도감은 수령했으면 `[0]` 이다.
    let claimedSteps: Set<Int>

    var id: String { dex.id }

    /// 목표 칸. 테마 도감은 「구성원 전부」 한 칸이다.
    var steps: [Int] {
        dex.kind == .set ? Array(dex.milestones.indices) : [0]
    }

    /// 이 칸에 필요한 종 수.
    func need(_ step: Int) -> Int {
        dex.kind == .set ? (dex.milestones[safe: step]?.need ?? total) : total
    }

    /// 이 칸의 보상.
    func reward(_ step: Int) -> DexReward {
        dex.kind == .set ? (dex.milestones[safe: step]?.reward ?? .none) : dex.reward
    }

    func isReached(_ step: Int) -> Bool { ownedCount >= need(step) }
    func isClaimed(_ step: Int) -> Bool { claimedSteps.contains(step) }

    /// 보상을 이미 수령했는가 — 마지막 칸까지 받았는지를 본다.
    ///
    /// 지금 보유 상태와 따로 둔다. 수령은 영구 기록이라, 나중에 도감에 카드가 추가돼
    /// 구성이 바뀌어도 이미 받은 혜택을 회수하지 않는다.
    var claimed: Bool { steps.last.map(isClaimed) ?? false }

    /// 지금 보유분만으로 마지막 칸을 만족하는가.
    var isFilled: Bool { steps.last.map(isReached) ?? false }

    /// 화면에서 완성으로 취급하는가.
    var isComplete: Bool { claimed || isFilled }

    /// 받을 것이 있는 칸. 목록에서 테두리로 드러낸다.
    var claimableStep: Int? {
        steps.first { isReached($0) && !isClaimed($0) && !reward($0).isEmpty }
    }

    var isClaimable: Bool { claimableStep != nil }

    /// 아직 도달하지 않은 첫 칸. 「다음 목표」로 적는다.
    var nextStep: Int? { steps.first { !isReached($0) } }

    var fraction: Double { total > 0 ? Double(ownedCount) / Double(total) : 0 }

    /// 다음 칸까지의 진행(0~1). 막대가 이 값을 쓴다.
    var stepFraction: Double {
        guard let next = nextStep else { return 1 }
        let want = need(next)
        return want > 0 ? min(1, Double(ownedCount) / Double(want)) : 1
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum DexProgress {

    /// 테마 도감의 진행.
    static func status(for dex: Dex, owned: (String) -> Bool,
                       claimed: Set<String>) -> DexStatus {
        status(for: dex, owned: owned, claimed: claimed, setCards: { _ in [] })
    }

    /// 칸이 하나인 도감의 진행 — 수령 여부를 참·거짓으로 준다.
    static func status(for dex: Dex, owned: (String) -> Bool, claimed: Bool) -> DexStatus {
        status(for: dex, owned: owned, claimed: claimed ? [dex.id] : [])
    }

    /// 진행을 잰다. **세트 도감은 그 세트의 종 목록이 필요하다** — 구성 카드를 들고 있지
    /// 않으므로 밖에서 받는다.
    static func status(for dex: Dex, owned: (String) -> Bool, claimed: Set<String>,
                       setCards: (String) -> [String]) -> DexStatus {
        if dex.kind == .set {
            let pool = setCards(dex.homeSet)
            let have = pool.reduce(0) { $0 + (owned($1) ? 1 : 0) }
            let steps = Set(dex.milestones.indices.filter { claimed.contains(dex.claimKey($0)) })
            return DexStatus(dex: dex, ownedCount: have, missing: [], total: pool.count,
                             claimedSteps: steps)
        }
        let missing = dex.cards.filter { !owned($0) }
        // 테마 도감의 수령 기록은 예전부터 id 하나였다. 새 열쇠(`id#0`)도 함께 본다 —
        // 이미 받은 사람의 기록이 무효가 되면 혜택이 사라진다.
        let got = claimed.contains(dex.id) || claimed.contains(dex.claimKey(0))
        return DexStatus(dex: dex, ownedCount: dex.cards.count - missing.count,
                         missing: missing, total: dex.cards.count,
                         claimedSteps: got ? [0] : [])
    }

    static func statuses(dexes: [Dex], owned: (String) -> Bool,
                         claimed: Set<String>,
                         setCards: @escaping (String) -> [String] = { _ in [] }) -> [DexStatus] {
        dexes.map { status(for: $0, owned: owned, claimed: claimed, setCards: setCards) }
    }

    /// 도감이 담고 있는 카드값의 합(달러). 난이도와 정렬의 기준이다.
    ///
    /// `dex.json` 에 든 값을 그대로 쓴다. 화면이 열릴 때마다 수백 장을 더할 이유가 없고,
    /// 저장된 값이 시세와 어긋나지 않는지는 테스트가 대조한다.
    static func value(of dex: Dex, prices: CardPrices? = CardPrices.shared) -> Double {
        dex.valueUSD
    }

    /// 시세에서 다시 계산한 값. 저장된 값과 대조할 때 쓴다.
    ///
    /// **세트 도감은 마지막 칸에 필요한 종만 센다.** 목표가 「전부」가 아니므로 세트 전체를
    /// 더하면 실제 목표보다 비싸게 잡힌다. 어느 종을 셀지는 생성기와 같은 규칙 —
    /// 값이 싼 것부터 `need` 장이다(무엇을 모으게 될지 고를 수 없으므로 바닥부터 찬다).
    static func recomputedValue(of dex: Dex, prices: CardPrices?,
                                index: CardIndex? = CardIndex.shared) -> Double {
        guard dex.kind == .set else {
            return dex.cards.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1, prices: prices) }
        }
        guard let index, let need = dex.milestones.last?.need else { return 0 }
        let sorted = index.cards(inSet: dex.homeSet)
            .map { MarketEconomy.usd(cardID: $0, prices: prices) }
            .sorted()
        return sorted.prefix(need).reduce(0, +)
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
    /// 도감 하나를 완성하는 데 필요한 팩 수. 갈래에 따라 셈법이 다르다.
    static func packsNeeded(for dex: Dex, quantile: Double, index: CardIndex,
                            perks: DexPerks = .none) -> Int {
        guard dex.kind == .set else {
            return packsNeeded(cards: dex.cards, quantile: quantile, index: index, perks: perks)
        }
        guard let need = dex.milestones.last?.need else { return 0 }
        return packsForDistinct(setID: dex.homeSet, need: need, index: index, perks: perks)
    }

    /// 그 세트에서 **서로 다른** `need` 종을 모으는 데 필요한 팩 수.
    ///
    /// 「전부 모으기」와 달리 기대 종수로 잰다 — 세트 도감은 몇 할까지가 목표이므로
    /// 「n 팩 뒤에 몇 종을 갖고 있을까」가 그대로 답이다. 전량을 재면 쿠폰 수집가 문제의
    /// 꼬리에 걸려 값이 수만 팩으로 튄다.
    static func packsForDistinct(setID: String, need: Int, index: CardIndex,
                                 perks: DexPerks = .none) -> Int {
        let probabilities = index.cards(inSet: setID)
            .map { pullProbability(cardID: $0, index: index, perks: perks) }
            .filter { $0 > 0 }
        guard !probabilities.isEmpty, need > 0 else { return 0 }
        var low = 1, high = 2_000_000
        while low < high {
            let mid = (low + high) / 2
            let distinct = probabilities.reduce(0.0) { $0 + (1 - pow(1 - $1, Double(mid))) }
            if distinct >= Double(need) { high = mid } else { low = mid + 1 }
        }
        return low
    }

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
