import Foundation

/// 오리파 — 카드샵이 팩을 미리 다 까서 상위 등급만 골라 담아 파는 뽑기.
///
/// 부스터 팩과 근본이 다르다. 팩은 매번 독립 추첨이지만 오리파는 **재고가 유한하다.**
/// 100슬롯짜리 박스에 무엇이 들었는지 미리 정해져 있고, 한 장씩 팔려 나가면 남은 것이 줄어든다.
/// "아직 UR 이 남아 있다" 는 긴장이 여기서 나온다.
///
/// 실물 오리파의 고질적인 문제는 검증 불가능성이다 — 공식 제품이 아니라서 당첨 카드가 실제로
/// 들어 있는지조차 확인할 수 없다. 여기서는 반대로 간다. **박스 안 카드를 전부 공개하고**
/// 남은 개수를 실시간으로 보여 준다. 팩 확률을 칸별로 공시하기로 한 것과 같은 원칙이다.
enum OripaConfig {

    /// 박스에 들어갈 수 있는 최저 등급. 오리파는 "상위 등급만 담은 뽑기" 다.
    static let minimumTier: CardTier = .doubleRare

    /// 박스 구성. **칸을 값의 배수 구간으로 적는다.**
    ///
    /// 등급으로 짜지 않는 이유는 그대로다 — 등급이 값을 뜻하지 않아서 값싼 UR 만 들어찬
    /// 박스가 나온다. 그래서 값으로 나누되, 나누는 방식을 바꿨다.
    ///
    /// 예전에는 **순위** 구간이었다(상위 1.2% 에서 한 장). 후보가 423장이던 시절에는 그
    /// 구간 안의 값이 고만고만해서 통했는데, 122세트 5,438장이 되면서 같은 구간에
    /// 109만원과 2,737만원이 함께 들어왔다. 25배다. 그 한 칸이 박스 값의 3분의 1이라
    /// 어떤 박스가 다른 박스의 세 배가 되는데 칸 값은 같았고, **박스 안이 다 보이는
    /// 뽑기에서 그건 「좋은 박스에서만 사면 된다」가 된다.**
    ///
    /// 이제 구간을 값의 배수로 적는다. 기준은 후보 시세의 중앙값이고, 한 구간 안의 값
    /// 차이를 좁혀 어느 박스든 총값이 ±5% 안에 들게 한다.
    ///
    /// 위쪽을 잘라 둔 것도 일부러다. 2,737만원짜리 카드는 80만원짜리 칸 100개에 넣을
    /// 물건이 아니다 — 그 한 장이 박스 전체보다 비싸다.
    static let composition: [(band: Range<Double>, count: Int)] = [
        (180.0..<200.0, 1),     // 최상위 — 슬롯 평균의 스무 배 남짓
        (55.0..<62.0, 4),
        (17.0..<20.0, 10),
        (5.2..<6.2, 15),
        (1.9..<2.2, 20),
        (0.55..<0.65, 50),
    ]

    static var slotsPerBox: Int { composition.reduce(0) { $0 + $1.count } }

    /// 한 슬롯이 갈리면 얼마가 되는가에 견준 값의 배수.
    ///
    /// 팩(`MarketEconomy.packMargin` = 3)보다 훨씬 비싸다. 오리파는 박스 안을 다 보고
    /// 원하는 카드를 노려 사는 방식이라 팩과 같은 배수로 두면 확정 구매가 더 싸진다.
    /// 이 값이면 갈아서 돌려받는 비율이 8분의 1이라 수익원이 될 수 없다.
    static let margin: Double = 8

    /// 박스를 만들 재료. **한 번 세워 두고 돌려 쓴다.**
    ///
    /// 예전에는 부를 때마다 후보 전체를 값순으로 다시 정렬했다. 비교 안에서 시세를 조회하는
    /// 정렬이라 5,438장이면 한 번에 13만 번 사전 조회가 일어나는데, 그것이 화면을 그릴
    /// 때마다 돌았다. 이제 장당 한 번만 조회하고 칸별 후보까지 한 번에 갈라 둔다.
    struct Shelf: Sendable {
        /// 칸마다의 후보. `composition` 과 같은 순서다.
        let bands: [[String]]
        /// 배수의 기준 — 후보 시세의 중앙값(달러).
        let baseUSD: Double
        /// 슬롯 하나의 기대 시세(달러).
        let slotUSD: Double

        var isEmpty: Bool { bands.allSatisfy(\.isEmpty) }
    }

    /// 후보를 값순으로 세우고 칸별로 갈라 둔다.
    static func shelf(index: CardIndex, prices: CardPrices? = CardPrices.shared) -> Shelf {
        shelf(cards: index.cards, prices: prices)
    }

    /// 인덱스를 조립하는 시점에 쓸 진입점. 이 결과를 `CardIndex`가 보관해 상점 화면을
    /// 다시 그릴 때마다 5천 장을 재정렬하지 않게 한다.
    static func shelf(cards: [CardEntry], prices: CardPrices? = CardPrices.shared) -> Shelf {
        // 값을 먼저 뽑아 두고 정렬한다. 비교 안에서 조회하면 같은 카드를 수십 번 찾는다.
        let keyed = cards
            .filter { $0.tier.rank >= minimumTier.rank }
            .map { (id: $0.id, usd: MarketEconomy.usd(cardID: $0.id, prices: prices)) }
            .sorted { $0.usd != $1.usd ? $0.usd > $1.usd : $0.id < $1.id }
        guard !keyed.isEmpty else { return Shelf(bands: [], baseUSD: 0, slotUSD: 0) }

        let base = keyed[keyed.count / 2].usd
        var bands: [[String]] = []
        var total = 0.0
        for entry in composition {
            let picked = window(entry.band, in: keyed, base: base, need: entry.count)
            bands.append(picked.map(\.id))
            guard !picked.isEmpty else { continue }
            let mean = picked.reduce(0.0) { $0 + $1.usd } / Double(picked.count)
            total += mean * Double(entry.count)
        }
        return Shelf(bands: bands, baseUSD: base, slotUSD: total / Double(slotsPerBox))
    }

    /// 값 구간에 드는 카드. 목록은 값이 큰 것부터라 구간은 이어진 한 토막이다.
    ///
    /// 후보가 칸 수보다 적으면 값이 가까운 쪽으로 넓힌다 — 칸을 비우느니 값이 조금
    /// 어긋나는 편이 낫다. 시세 스냅샷이 크게 바뀌어 한 구간이 비는 날에도 박스는 채워진다.
    private static func window(_ band: Range<Double>,
                               in keyed: [(id: String, usd: Double)],
                               base: Double, need: Int) -> ArraySlice<(id: String, usd: Double)> {
        let high = band.upperBound * base, low = band.lowerBound * base
        var lower = keyed.firstIndex { $0.usd < high } ?? keyed.count
        var upper = keyed.firstIndex { $0.usd < low } ?? keyed.count
        while upper - lower < need, lower > 0 || upper < keyed.count {
            if lower > 0 { lower -= 1 }
            if upper < keyed.count { upper += 1 }
        }
        return keyed[lower..<upper]
    }

    /// 슬롯 하나의 값. 박스 기대 시세에서 나온다.
    static func slotPrice(index: CardIndex, prices: CardPrices? = CardPrices.shared) -> Int {
        slotPrice(shelf: index.oripaShelf, prices: prices)
    }

    static func slotPrice(shelf: Shelf, prices: CardPrices? = CardPrices.shared) -> Int {
        guard shelf.slotUSD > 0 else { return 30_000_000 }
        return MarketEconomy.tokens(usd: shelf.slotUSD * margin, prices: prices)
    }

    /// 박스에 들어갈 수 있는 카드를 시세 높은 순으로.
    static func eligible(index: CardIndex, prices: CardPrices?) -> [String] {
        index.cards
            .filter { $0.tier.rank >= minimumTier.rank }
            .map { (id: $0.id, usd: MarketEconomy.usd(cardID: $0.id, prices: prices)) }
            .sorted { $0.usd != $1.usd ? $0.usd > $1.usd : $0.id < $1.id }
            .map(\.id)
    }
}

/// 뽑기 한 박스. 남은 슬롯이 곧 재고다.
struct OripaBox: Codable, Sendable, Equatable {
    /// 남은 카드 ID. 한 장 뽑으면 여기서 빠진다.
    var slots: [String]
    /// 몇 번째 박스인가. 다 팔리면 새 박스가 들어오고 이 값이 오른다.
    var serial: Int

    var remaining: Int { slots.count }

    var isEmpty: Bool { slots.isEmpty }
}

enum Oripa {

    /// 새 박스를 만든다. 칸마다 정해진 수만큼 서로 다른 카드를 고른다.
    ///
    /// 같은 카드를 두 번 넣지 않는다 — 100슬롯을 다 사면 박스 안의 것을 전부 갖게 되는 것이
    /// 이 뽑기의 확정 경로이고, 중복이 섞이면 그 약속이 깨진다.
    static func makeBox(index: CardIndex, serial: Int,
                        prices: CardPrices? = CardPrices.shared,
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        // `prices`는 기존 호출부 호환용이다. 선반은 이 인덱스가 만들어질 때의 시세와 한 묶음이고,
        // 화면을 그릴 때 다른 스냅샷으로 다시 세우면 캐시 계약과 박스 가격이 갈라진다.
        _ = prices
        return makeBox(shelf: index.oripaShelf, serial: serial, using: &generator)
    }

    static func makeBox(shelf: OripaConfig.Shelf, serial: Int,
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        var slots: [String] = []
        var taken: Set<String> = []
        for (entry, candidates) in zip(OripaConfig.composition, shelf.bands) {
            var pool = candidates.filter { !taken.contains($0) }
            for _ in 0..<entry.count {
                guard !pool.isEmpty else { break }
                let pick = Int(generator.next(upperBound: UInt64(pool.count)))
                let id = pool.remove(at: pick)
                taken.insert(id)
                slots.append(id)
            }
        }
        return OripaBox(slots: slots, serial: serial)
    }

    /// 한 슬롯을 뽑는다. 남은 것 중 무작위로 하나를 빼서 돌려준다.
    static func pull(from box: inout OripaBox,
                     using generator: inout some RandomNumberGenerator) -> String? {
        guard !box.slots.isEmpty else { return nil }
        let pick = Int(generator.next(upperBound: UInt64(box.slots.count)))
        return box.slots.remove(at: pick)
    }

    /// 남은 등급별 개수. 화면이 "UR 아직 1장 남음" 을 보여줄 때 쓴다.
    static func remainingByTier(_ box: OripaBox, index: CardIndex) -> [(tier: CardTier, count: Int)] {
        var counts: [CardTier: Int] = [:]
        for id in box.slots {
            guard let tier = index.card(id)?.tier else { continue }
            counts[tier, default: 0] += 1
        }
        return counts.map { (tier: $0.key, count: $0.value) }
            .sorted { $0.tier.rank > $1.tier.rank }
    }

    /// 값이 비싼 것부터. 컬렉션·도감이 쓰는 기준을 박스 안에서도 그대로 쓴다 —
    /// 화면마다 정렬이 다르면 같은 카드가 어디에 있는지 매번 다시 찾아야 한다.
    static func sortedByValue(_ ids: [String], index: CardIndex,
                              prices: CardPrices? = CardPrices.shared) -> [String] {
        ids.sorted { a, b in
            let pa = MarketEconomy.usd(cardID: a, prices: prices)
            let pb = MarketEconomy.usd(cardID: b, prices: prices)
            if pa != pb { return pa > pb }
            let ra = index.card(a)?.tier.rank ?? 0, rb = index.card(b)?.tier.rank ?? 0
            if ra != rb { return ra > rb }
            return a < b
        }
    }
}
