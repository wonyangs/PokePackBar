import Foundation

/// 오리파 — 카드샵이 팩을 미리 다 까서 상위 등급만 골라 담아 파는 뽑기.
///
/// 부스터 팩과 근본이 다르다. 팩은 매번 독립 추첨이지만 오리파는 **재고가 유한하다.**
/// 40봉투짜리 박스에 무엇이 들었는지 미리 정해져 있고, 한 장씩 팔려 나가면 남은 것이 줄어든다.
/// "아직 UR 이 남아 있다" 는 긴장이 여기서 나온다.
///
/// 실물 오리파의 고질적인 문제는 검증 불가능성이다 — 공식 제품이 아니라서 당첨 카드가 실제로
/// 들어 있는지조차 확인할 수 없다. 여기서는 반대로 간다. **박스 안 카드를 전부 공개하고**
/// 남은 개수를 실시간으로 보여 준다. 팩 확률을 칸별로 공시하기로 한 것과 같은 원칙이다.
enum OripaConfig {

    /// 박스에 들어갈 수 있는 최저 등급. 오리파는 "상위 등급만 담은 뽑기" 다.
    static let minimumTier: CardTier = .doubleRare

    /// 박스 구성. **칸을 「대표 카드에 대한 비율」로 적는다.**
    ///
    /// 예전에는 후보 시세의 중앙값에 대한 배수였다. 그러면 박스 규모가 못박히고, 1등 칸에
    /// 넣을 수 있는 카드도 그 규모에 갇힌다 — 뽑기값 21만원짜리 박스의 1등은 77만원이고,
    /// 그건 「이 박스의 얼굴」이라 부를 만한 카드가 아니다.
    ///
    /// **이제 대표 카드를 먼저 고르고 나머지를 거기에 비례해 채운다.** 대표 카드가 100만원인
    /// 박스도 있고 1,000만원인 박스도 있으며, 박스가 통째로 그만큼 커진다. 비율이 고정이라
    /// 어느 박스에서 뽑든 본전 칸 수와 바닥은 같다.
    ///
    /// 예산이 어디로 가는지가 이 표의 전부다.
    ///
    /// ```
    /// Σ(확률 × 뽑기값 대비 배수) = 1 / margin
    /// ```
    ///
    /// 이 합이 고정이라 **본전 이상인 칸은 회수율을 넘을 수 없다.** 예산을 1등에 다 몰아주면
    /// 나머지 39칸이 전부 손해가 되는데, 박스 안이 다 보이는 뽑기에서 그건 「39/40 확률로
    /// 지는 것이 화면에 적혀 있는 것」이다. 그래서 1등을 뽑기값의 6배로 두고 본전 칸 넷을
    /// 따로 뒀다 — 다섯 칸(12%)이 본전 이상이다.
    ///
    /// `spread` 는 그 칸에 들어갈 카드의 값이 비율에서 얼마나 벗어나도 되는가다.
    /// **본전 칸만 좁게 잡는다** — 넓으면 아래로 벗어난 카드가 본전을 못 넘어, 다섯 칸이라
    /// 적어 놓고 실제로는 셋만 넘는 박스가 나온다.
    static let composition: [(ratio: Double, count: Int, spread: Double)] = [
        (1.0, 1, 0.0),          // 대표 카드 — 뽑기값의 6배
        (0.180, 4, 0.06),       // 본전 칸 — 뽑기값의 1.07배
        (0.0367, 10, 0.12),     // 뽑기값의 22%
        (0.0240, 25, 0.12),     // 바닥 — 뽑기값의 14%
    ]

    /// 대표 카드를 고르는 값 구간. 후보 시세 중앙값의 배수다.
    ///
    /// **박스마다 규모가 달라지는 것이 목적이다.** 25배(약 32만원)면 뽑기 5만원대 박스이고,
    /// 500배(약 638만원)면 뽑기 100만원대 박스다. 교체가 공짜이므로 이 폭이 곧 「어느 판에서
    /// 놀지 고르는 것」이 된다 — 공짜 교체가 그동안 아무 의미가 없었던 것을 여기서 쓴다.
    ///
    /// 위를 잘라 둔 이유는 후보가 마르기 때문이다. 대표가 638만원이면 본전 칸은 112만원인데
    /// 그 값대 카드가 서른 장 남짓뿐이라, 더 올리면 박스마다 같은 카드가 돌아간다.
    static let headlineBand: Range<Double> = 25.0..<500.0

    /// 대표 카드가 뽑기값의 몇 배인가. 화면과 문서가 이 값을 인용한다.
    static var headlineMultiple: Double {
        let n = Double(slotsPerBox)
        return n / (margin * composition.reduce(0.0) { $0 + $1.ratio * Double($1.count) })
    }

    static var slotsPerBox: Int { composition.reduce(0) { $0 + $1.count } }

    /// 한 슬롯이 갈리면 얼마가 되는가에 견준 값의 배수.
    ///
    /// 예전에는 8이었고 근거는 "박스 안을 다 보고 노려 사는 방식이라 팩과 같은 배수면
    /// 확정 구매가 더 싸진다" 였다. 그런데 그 확정 구매, 즉 박스 완주는 7천8백만원이었다.
    /// 일어나지 않는 경로를 막느라 실제로 일어나는 경로를 망가뜨린 값이다.
    ///
    /// **팩(3)보다 조금 후하게 둔다.** 회수율이 곧 본전 칸의 상한이라(`composition` 주석),
    /// 3으로는 본전 칸을 늘리면서 바닥을 지킬 수 없다. 2.5 면 40% 가 돌아온다.
    ///
    /// 팩보다 후한 것이 정당한 이유는 **오리파는 한 장뿐**이라는 데 있다. 팩은 열 장 중
    /// 하나만 좋으면 만족하는데 오리파는 그 한 장이 전부라 같은 기대값이어도 체감이 나쁘다.
    /// 게다가 전부 RR 이상이라 도감이 요구하는 낮은 등급을 못 채운다 — 팩을 대체하지 않는다.
    static let margin: Double = 2.5

    /// 박스를 만들 재료. **한 번 세워 두고 돌려 쓴다.**
    ///
    /// 부를 때마다 후보 전체를 값순으로 다시 정렬하면 5,438장이 매번 재정렬된다. 비교 안에서
    /// 시세를 조회하는 정렬이라 한 번에 13만 번 사전 조회가 일어나고, 그것이 화면을 그릴
    /// 때마다 돌았다. 장당 한 번만 조회하고 정렬해 둔다.
    ///
    /// 칸별 후보를 미리 갈라 두지 않는다 — 대표 카드가 정해져야 나머지 칸의 값이 정해지고,
    /// 그건 박스를 만들 때 알 수 있다. 정렬된 목록에서 이진 탐색으로 자르므로 박스를 만드는
    /// 비용은 그대로다(박스는 새로 받을 때만 만든다).
    struct Shelf: Sendable {
        /// 후보 전체. **값 내림차순**이다.
        let keyed: [(id: String, usd: Double)]
        /// 후보 시세의 중앙값(달러). 대표 카드 구간의 기준이다.
        let baseUSD: Double

        var isEmpty: Bool { keyed.isEmpty }

        /// 값 구간에 드는 후보. 목록이 내림차순이라 구간은 이어진 한 토막이다.
        ///
        /// 후보가 필요한 수보다 적으면 값이 가까운 쪽으로 넓힌다 — 칸을 비우느니 값이 조금
        /// 어긋나는 편이 낫다. 시세 스냅샷이 크게 바뀌어 한 구간이 비는 날에도 박스는 찬다.
        func candidates(around usd: Double, spread: Double, need: Int)
            -> ArraySlice<(id: String, usd: Double)> {
            window(low: usd * (1 - spread), high: usd * (1 + spread), need: need)
        }

        /// 값 구간에서 **값 기준으로 고르게** 한 장 뽑는다.
        ///
        /// 후보 목록에서 그냥 무작위로 집으면 안 된다. 카드값 분포가 아래로 심하게 쏠려 있어
        /// 32만원 근처 후보가 638만원 근처보다 수백 배 많고, 그러면 큰 박스가 사실상 안 나온다.
        /// 목표 값을 로그 균등으로 정한 뒤 거기에 가장 가까운 카드를 집는다.
        func pickByValue(low: Double, high: Double,
                         using generator: inout some RandomNumberGenerator) -> (id: String, usd: Double)? {
            guard !keyed.isEmpty, low > 0, high > low else { return keyed.first }
            let t = Double.random(in: 0..<1, using: &generator)
            let target = low * pow(high / low, t)
            return window(low: target * 0.94, high: target * 1.06, need: 1).randomElement(using: &generator)
        }

        func window(low: Double, high: Double, need: Int) -> ArraySlice<(id: String, usd: Double)> {
            var lower = keyed.firstIndex { $0.usd <= high } ?? keyed.count
            var upper = keyed.firstIndex { $0.usd < low } ?? keyed.count
            while upper - lower < need, lower > 0 || upper < keyed.count {
                if lower > 0 { lower -= 1 }
                if upper < keyed.count { upper += 1 }
            }
            return keyed[lower..<upper]
        }
    }

    /// 후보를 값순으로 세운다.
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
        guard !keyed.isEmpty else { return Shelf(keyed: [], baseUSD: 0) }
        return Shelf(keyed: keyed, baseUSD: keyed[keyed.count / 2].usd)
    }

    /// 대표 카드가 이 값일 때의 뽑기값. 박스마다 규모가 다르므로 **진열에 적을 「이 오리파는
    /// 얼마」는 없다** — 화면은 지금 걸려 있는 박스의 값(`slotPrice(box:)`)을 쓴다.
    ///
    /// 문서와 테스트가 「보통 박스는 얼마인가」를 물을 때 쓰는 대표값이다.
    static func slotPrice(headlineUSD: Double, prices: CardPrices? = CardPrices.shared) -> Int {
        guard headlineUSD > 0 else { return 30_000_000 }
        return MarketEconomy.tokens(usd: headlineUSD / headlineMultiple, prices: prices)
    }

    /// 대표 카드 구간의 한가운데를 기준으로 한 뽑기값. 「보통 박스」의 값이다.
    static func typicalSlotPrice(shelf: Shelf, prices: CardPrices? = CardPrices.shared) -> Int {
        guard !shelf.isEmpty else { return 30_000_000 }
        let mid = (headlineBand.lowerBound * headlineBand.upperBound).squareRoot()
        return slotPrice(headlineUSD: mid * shelf.baseUSD, prices: prices)
    }

    /// **지금 이 박스에서** 한 봉투를 여는 값. 남은 봉투의 기대 시세에서 낸다.
    ///
    /// 예전에는 박스가 얼마나 비었든 같은 값을 받았다. 상위 다섯 장이 이미 빠진 박스에서도
    /// 78만원, 바닥만 남은 박스에서도 78만원이었다. **안을 다 보여 주기로 해 놓고 그 정보를
    /// 값에 반영하지 않으면 보여 줄 이유가 없다.**
    ///
    /// 기대 회수율은 어느 상태에서든 `1/margin` 으로 같다. 바뀌는 것은 값과 분산이 함께
    /// 움직인다는 것뿐이다 — 1등을 뽑고 나면 나머지를 싸게 쓸어 담을 수 있다.
    static func slotPrice(box: OripaBox, prices: CardPrices? = CardPrices.shared) -> Int {
        let left = box.slots
        guard !left.isEmpty else { return 0 }
        let mean = left.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1, prices: prices) }
            / Double(left.count)
        guard mean > 0 else { return 30_000_000 }
        return MarketEconomy.tokens(usd: mean * margin, prices: prices)
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

/// 뽑기 한 박스. 남은 봉투가 곧 재고다.
///
/// **첨자가 곧 봉투 번호다.** 박스를 만들 때 어느 봉투에 무엇이 들었는지 정하고 그 뒤로
/// 바꾸지 않는다. 봉투를 누른 다음에 카드를 정하면 고르는 행위가 장식이 되는데, 화면에서
/// 구별할 수 없으니 들키지도 않는다. 그래서 더더욱 하지 않는다 — 이 앱이 실물 오리파와
/// 갈라선 지점이 "안을 다 보여 준다" 이기 때문이다.
///
/// 뽑은 봉투를 목록에서 빼지 않고 `opened` 로 표시하는 이유도 같다. 빼면 뒤 봉투의 번호가
/// 밀리고, 박스를 다 비운 뒤에 대응표를 보여 줄 수 없다.
struct OripaBox: Codable, Sendable, Equatable {
    /// 봉투에 든 카드. 첨자가 봉투 번호다. 만들고 나면 바뀌지 않는다.
    var cards: [String]
    /// 이미 연 봉투 번호.
    var opened: Set<Int>
    /// 몇 번째 박스인가. 다 팔리면 새 박스가 들어오고 이 값이 오른다.
    var serial: Int

    init(cards: [String], opened: Set<Int> = [], serial: Int) {
        self.cards = cards
        self.opened = opened
        self.serial = serial
    }

    /// 아직 안 열린 봉투에 든 카드. 값과 남은 등급을 셀 때 쓴다.
    var slots: [String] { cards.indices.filter { !opened.contains($0) }.map { cards[$0] } }

    var remaining: Int { cards.count - opened.count }

    var isEmpty: Bool { remaining == 0 }

    /// 이 봉투에 든 카드. 아직 안 연 봉투는 nil 을 돌려준다 — 화면이 실수로 물어보더라도
    /// 답이 새지 않아야 한다.
    func card(at envelope: Int) -> String? {
        guard opened.contains(envelope), cards.indices.contains(envelope) else { return nil }
        return cards[envelope]
    }

    /// 예전 박스를 읽는다. `slots` 만 있던 시절에는 남은 카드만 들고 있었다.
    ///
    /// 그대로 봉투로 옮긴다. 몇 개를 뽑았는지는 잃지만 남은 카드는 지킨다 — 100칸 박스는
    /// 봉투 수가 맞지 않아 어차피 `WalletStore` 가 새로 채운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serial = (try? c.decode(Int.self, forKey: .serial)) ?? 1
        opened = (try? c.decode(Set<Int>.self, forKey: .opened)) ?? []
        if let cards = try? c.decode([String].self, forKey: .cards) {
            self.cards = cards
        } else {
            cards = (try? c.decode([String].self, forKey: .slots)) ?? []
            opened = []
        }
    }

    /// 손으로 적는다. `slots` 는 읽기 전용 옛 이름이라 자동 합성에 맡길 수 없다.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cards, forKey: .cards)
        try c.encode(opened, forKey: .opened)
        try c.encode(serial, forKey: .serial)
    }

    private enum CodingKeys: String, CodingKey {
        case cards, opened, serial
        /// 예전 이름. 읽기만 한다.
        case slots
    }
}

enum Oripa {

    /// 새 박스를 만든다. 칸마다 정해진 수만큼 서로 다른 카드를 고른다.
    ///
    /// **대표 카드를 먼저 고르고 나머지를 거기에 비례해 채운다.** 그래서 박스마다 규모가
    /// 다르다 — 대표가 100만원인 박스도 있고 1,000만원인 박스도 있다.
    ///
    /// 같은 카드를 두 번 넣지 않는다 — 40봉투를 다 사면 박스 안의 것을 전부 갖게 되는 것이
    /// 이 뽑기의 확정 경로이고, 중복이 섞이면 그 약속이 깨진다.
    ///
    /// `owns` 로 **이미 가진 카드를 뒤로 미룬다.** 최소 보상을 올리는 방법은 두 가지인데,
    /// 바닥 칸의 값을 올리는 것은 회수율이 고정이라 천장을 깎아야 한다. 미보유로 채우는 것은
    /// 기대값을 건드리지 않고 바닥의 성격만 바꾼다 — "8천원짜리 중복" 이 "새 카드 확정" 이
    /// 된다. 후보가 5천 장 넘으므로 한동안은 채워진다.
    static func makeBox(index: CardIndex, serial: Int,
                        prices: CardPrices? = CardPrices.shared,
                        owns: (String) -> Bool = { _ in false },
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        // `prices`는 기존 호출부 호환용이다. 선반은 이 인덱스가 만들어질 때의 시세와 한 묶음이고,
        // 화면을 그릴 때 다른 스냅샷으로 다시 세우면 캐시 계약과 박스 가격이 갈라진다.
        _ = prices
        return makeBox(shelf: index.oripaShelf, serial: serial, owns: owns, using: &generator)
    }

    static func makeBox(shelf: OripaConfig.Shelf, serial: Int,
                        owns: (String) -> Bool = { _ in false },
                        using generator: inout some RandomNumberGenerator) -> OripaBox {
        guard !shelf.isEmpty else { return OripaBox(cards: [], serial: serial) }

        // **대표 카드를 먼저 고른다.** 나머지 칸의 값이 여기서 나오므로 순서가 뒤바뀔 수 없다.
        let band = OripaConfig.headlineBand
        guard let headline = shelf.pickByValue(low: band.lowerBound * shelf.baseUSD,
                                               high: band.upperBound * shelf.baseUSD,
                                               using: &generator) else {
            return OripaBox(cards: [], serial: serial)
        }

        var cards: [String] = [headline.id]
        var taken: Set<String> = [headline.id]
        for entry in OripaConfig.composition.dropFirst() {
            let free = shelf.candidates(around: headline.usd * entry.ratio,
                                        spread: entry.spread, need: entry.count * 3)
                .filter { !taken.contains($0.id) }
            // 미보유부터 쓰고, 그 칸에서 동나면 가진 카드로 메운다. 칸을 비우는 것보다 낫다.
            var fresh = free.filter { !owns($0.id) }.map(\.id)
            var spare = free.filter { owns($0.id) }.map(\.id)
            for _ in 0..<entry.count {
                guard !fresh.isEmpty || !spare.isEmpty else { break }
                let id = !fresh.isEmpty ? take(&fresh, using: &generator)
                                        : take(&spare, using: &generator)
                taken.insert(id)
                cards.append(id)
            }
        }
        // **자리를 섞는다.** 칸 순서대로 담으면 0번 봉투가 늘 대표 카드다.
        cards.shuffle(using: &generator)
        return OripaBox(cards: cards, serial: serial)
    }

    private static func take(_ pool: inout [String],
                             using generator: inout some RandomNumberGenerator) -> String {
        pool.remove(at: Int(generator.next(upperBound: UInt64(pool.count))))
    }

    /// 고른 봉투를 연다. 이미 연 봉투나 없는 번호면 아무것도 하지 않는다.
    static func open(_ envelope: Int, in box: inout OripaBox) -> String? {
        guard box.cards.indices.contains(envelope), !box.opened.contains(envelope) else {
            return nil
        }
        box.opened.insert(envelope)
        return box.cards[envelope]
    }

    /// 이 박스의 **대표 카드** — 값이 가장 비싼 한 장.
    ///
    /// 이미 뽑혀 나갔어도 대표는 대표다(`cards` 전체에서 찾는다). 공지 보드가 그 자리에
    /// 「대표」라 적어 두어야, 남은 것만 보고 「이 박스는 뭐가 걸렸었나」를 알 수 있다.
    static func headline(of box: OripaBox, prices: CardPrices? = CardPrices.shared) -> String? {
        box.cards.max { MarketEconomy.usd(cardID: $0, prices: prices)
                            < MarketEconomy.usd(cardID: $1, prices: prices) }
    }

    /// 이 카드가 들어 있던 봉투 번호. **안 연 봉투는 nil 이다.**
    ///
    /// 공지 보드는 박스에 든 카드를 전부 늘어놓는데, 거기서 카드마다 봉투 번호를 적으면
    /// **대응표가 통째로 샌다** — 목록에서 1등을 찾아 번호를 읽고 그 봉투를 누르면 되므로
    /// 고르는 일이 사라진다. 실제로 그렇게 나갔다.
    ///
    /// 번호를 물어보는 곳이 이 함수 하나여야 한다. 뷰에서 `cards` 를 직접 훑으면 안 연
    /// 봉투의 번호도 손에 들어오고, 그러면 다음에 또 샌다.
    static func revealedEnvelope(of cardID: String, in box: OripaBox) -> Int? {
        box.opened.first { box.cards.indices.contains($0) && box.cards[$0] == cardID }
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
