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

    /// 박스 구성. **등급이 아니라 값으로 칸을 나눈다.**
    ///
    /// 예전에는 UR 1장·SAR 4장처럼 등급으로 짰다. 등급이 값을 뜻하지 않으므로 그렇게 짜면
    /// 값싼 UR 만 들어찬 박스와 비싼 것만 들어찬 박스의 가치가 몇 배씩 갈리는데, 값은 같다.
    ///
    /// 후보를 시세 순으로 세운 뒤 순위 구간에서 뽑으면 어느 박스든 값의 윤곽이 같아진다.
    /// 맨 위 칸은 늘 "이 게임에서 제일 비싼 다섯 장 중 하나" 다.
    static let composition: [(band: Range<Double>, count: Int)] = [
        (0.00..<0.012, 1),    // 최상위 — 후보 423장 기준 상위 5장
        (0.012..<0.06, 4),
        (0.06..<0.18, 10),
        (0.18..<0.36, 15),
        (0.36..<0.60, 20),
        (0.60..<1.00, 50),
    ]

    static var slotsPerBox: Int { composition.reduce(0) { $0 + $1.count } }

    /// 한 슬롯이 갈리면 얼마가 되는가에 견준 값의 배수.
    ///
    /// 팩(`MarketEconomy.packMargin` = 3)보다 훨씬 비싸다. 오리파는 박스 안을 다 보고
    /// 원하는 카드를 노려 사는 방식이라 팩과 같은 배수로 두면 확정 구매가 더 싸진다.
    /// 이 값이면 갈아서 돌려받는 비율이 8분의 1이라 수익원이 될 수 없다.
    static let margin: Double = 8

    /// 슬롯 하나의 값. 박스 기대 시세에서 나온다.
    static func slotPrice(index: CardIndex, prices: CardPrices? = CardPrices.shared) -> Int {
        let pool = eligible(index: index, prices: prices)
        guard !pool.isEmpty else { return 30_000_000 }
        let mean = expectedSlotUSD(pool: pool, prices: prices)
        return MarketEconomy.tokens(usd: mean * margin)
    }

    /// 박스에 들어갈 수 있는 카드를 시세 높은 순으로.
    static func eligible(index: CardIndex, prices: CardPrices?) -> [String] {
        index.cards
            .filter { $0.tier.rank >= minimumTier.rank }
            .map(\.id)
            .sorted { MarketEconomy.usd(cardID: $0, prices: prices)
                    > MarketEconomy.usd(cardID: $1, prices: prices) }
    }

    /// 슬롯 하나의 기대 시세 — 구간마다 그 구간 평균을 쓰고 칸 수로 가중한다.
    static func expectedSlotUSD(pool: [String], prices: CardPrices?) -> Double {
        var total = 0.0
        for entry in composition {
            let range = bounds(entry.band, count: pool.count)
            guard !range.isEmpty else { continue }
            let mean = range.reduce(0.0) {
                $0 + MarketEconomy.usd(cardID: pool[$1], prices: prices)
            } / Double(range.count)
            total += mean * Double(entry.count)
        }
        return total / Double(slotsPerBox)
    }

    /// 비율 구간을 실제 순위 구간으로 옮긴다. 후보가 적어도 최소 한 장은 잡는다.
    static func bounds(_ band: Range<Double>, count: Int) -> Range<Int> {
        let lower = min(count - 1, Int(band.lowerBound * Double(count)))
        let upper = min(count, max(lower + 1, Int(band.upperBound * Double(count))))
        return lower..<upper
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

    /// 새 박스를 만든다. 등급별로 정해진 수만큼 서로 다른 카드를 고른다.
    ///
    /// 같은 카드를 두 번 넣지 않는다 — 100슬롯을 다 사면 박스 안의 것을 전부 갖게 되는 것이
    /// 이 뽑기의 확정 경로이고, 중복이 섞이면 그 약속이 깨진다.
    static func makeBox(index: CardIndex, serial: Int,
                        prices: CardPrices? = CardPrices.shared,
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        let ranked = OripaConfig.eligible(index: index, prices: prices)
        var slots: [String] = []
        var taken: Set<String> = []
        for entry in OripaConfig.composition {
            var pool = OripaConfig.bounds(entry.band, count: ranked.count)
                .map { ranked[$0] }
                .filter { !taken.contains($0) }
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
