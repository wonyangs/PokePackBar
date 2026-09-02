import Foundation

/// 팩 시대. **실물 팩은 시대마다 장수도, 칸 구성도, 봉입률도 다르다.**
///
/// 1999년 팩은 11장이고 역홀로 칸이 없다. e-Card 부터 역홀로가 생기면서 9장으로 줄었고,
/// Diamond & Pearl 부터 10장으로 굳었다. 표 하나로 122세트를 덮으면 어느 시대에도 맞지
/// 않는 팩이 된다.
///
/// **시리즈 이름이 아니라 발매일로 가른다.** 시리즈는 옛 인덱스에 없을 수 있고, 새 세트는
/// 날짜만 있으면 저절로 제자리를 찾는다.
enum PackEra: String, Sendable, CaseIterable {
    /// Base·Gym·Neo·레전드 컬렉션 (1999/01~2002/05). 11장, 역홀로 없음.
    case wotc
    /// e-Card·EX (2002/09~2007/02). 9장, 역홀로 도입.
    case ex
    /// Diamond & Pearl·Platinum·HGSS (2007/05~2011/02). 10장.
    case diamondPearl
    /// Black & White·XY (2011/04~2016/11). 10장.
    case blackWhite
    /// Sun & Moon (2017/02~2019/11). 10장.
    case sunMoon
    /// Sword & Shield (2020/02~2023/01). 10장.
    case swordShield
    /// Scarlet & Violet·Mega Evolution (2023/03~). 10장.
    case scarletViolet

    /// 이 시대가 시작하는 발매일. 인덱스의 `released`("2003/07/01") 와 문자열 그대로 견준다 —
    /// 자릿수가 고정이라 사전순이 곧 날짜순이다.
    var from: String {
        switch self {
        case .wotc:          return "0000/00/00"
        case .ex:            return "2002/09/01"
        case .diamondPearl:  return "2007/05/01"
        case .blackWhite:    return "2011/04/01"
        case .sunMoon:       return "2017/02/01"
        case .swordShield:   return "2020/02/01"
        case .scarletViolet: return "2023/03/01"
        }
    }

    /// 발매일이 속한 시대. 날짜를 모르는 세트는 최신 구성으로 본다.
    static func of(released: String) -> PackEra {
        allCases.last { released >= $0.from } ?? .scarletViolet
    }
}

/// 팩 구성과 확률. **값은 실물 팩에서 온다.**
///
/// 예전에는 열 칸을 우리가 정한 표로 굴렸다. 어느 칸에서도 UR 까지 나올 수 있었고, 실물보다
/// 후하다는 이유로 그렇게 두었다. 실물은 그렇지 않다 — 커먼 칸에서는 커먼만 나오고 레어는
/// 한 칸에서만 나온다. 지금은 실물 구조를 그대로 쓰고, Sword & Shield 와 Scarlet & Violet
/// 은 표본 개봉으로 잰 값을 그대로 옮겼다.
///
/// **가중치는 만분율이다**(10000 = 100%). 실측 봉입률을 반올림 없이 적으려는 것이다.
enum PackConfig {

    // MARK: 칸 표 — 커먼·언커먼

    /// 커먼 칸. **기본 에너지가 여기 섞인다.**
    ///
    /// 옛 팩은 에너지를 따로 보장하지 않았고 커먼 자리에 한 장쯤 들어 있었다(11장 팩의
    /// 커먼 7칸에 한 장이면 14%). 최신 세트는 기본 에너지가 재판이라 세트 목록에 없으므로,
    /// 그런 세트에서는 이 몫이 커먼으로 돌아간다.
    static let commonWeights: [(tier: CardTier, weight: Int)] = [
        (.common, 8600), (.energy, 1400),
    ]

    /// 언커먼 칸.
    static let uncommonWeights: [(tier: CardTier, weight: Int)] = [(.uncommon, 10000)]

    // MARK: 칸 표 — 역홀로

    /// 역홀로 칸은 e-Card(2002) 부터 생겼다. 대부분은 커먼·언커먼의 반짝이 판이다.
    static let exReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5500), (.uncommon, 3500), (.rare, 1000),
    ]

    static let diamondPearlReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5500), (.uncommon, 3400), (.rare, 1100),
    ]

    static let blackWhiteReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5400), (.uncommon, 3400), (.rare, 1200),
    ]

    static let sunMoonReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5300), (.uncommon, 3400), (.rare, 1300),
    ]

    /// Sword & Shield — 어메이징레어와 찬란한(K)이 이 칸에서 1% 로 섞인다.
    /// 실물도 찬란한 카드가 역홀로 자리를 대신 차지하는 방식이었다.
    static let swordShieldReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5200), (.uncommon, 3300), (.rare, 1400),
        (.tripleRare, 10), (.amazing, 30), (.radiant, 60),
    ]

    /// Scarlet & Violet — **실측값**이다.
    ///
    /// 일러스트레어 7.69%, 스페셜아트레어 3.11%, 하이퍼레어 1.92% 가 이 칸에서 나온다.
    /// SV 의 상위 등급이 레어 칸이 아니라 역홀로 칸에서 나온다는 것이 이 시대의 핵심이고,
    /// 그래서 "레어 칸 확률" 만 적으면 실제와 어긋난다. 남는 87.28% 는 커먼·언커먼·레어의
    /// 역홀로이며 세트의 장수 비율(대략 56:32:12)로 나눴다.
    /// 샤이니(S)도 이 칸이다 — 「팔데아의 운명」처럼 이로치가 주력인 세트에서 역홀로
    /// 자리를 대신 차지한다. 실측한 세 값(AR·SAR·UR)은 건드리지 않고 유도값인 커먼 몫에서 뗐다.
    static let scarletVioletReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4805), (.uncommon, 2790), (.rare, 1048), (.shiny, 46), (.shinyUltra, 5),
        (.artRare, 769), (.specialArtRare, 311), (.ultraRare, 192),
        (.megaUltraRare, 20), (.blackWhiteRare, 14),
    ]

    // MARK: 칸 표 — 레어 칸

    /// 1999~2002. 레어 한 칸이고 홀로는 그중 3분의 1이다.
    /// 빛나는 포켓몬·다크 라이츄 같은 시크릿은 팩 서른 개에 한 장꼴이다.
    static let wotcRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 6550), (.doubleRare, 3200), (.shining, 200), (.ultraRare, 50),
    ]

    /// e-Card·EX (2002~2007). 홀로 자리에 ex 가 섞이고 골드스타가 1/72 로 들어온다.
    ///
    /// 골드스타는 나무위키 등급표에 없어 SR 로 넣는다 — 「박스당 0~1장」이라는 SR 설명과
    /// 봉입률이 맞는다. 카드 상세에는 「★ (골드스타)」로 적힌다.
    static let exRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 6400), (.doubleRare, 3400), (.superRare, 140), (.ultraRare, 60),
    ]

    /// Diamond & Pearl·Platinum·HGSS (2007~2011).
    ///
    /// LV.X·Prime·LEGEND 는 나무위키 등급표에 없다. 셋 다 그 시대의 간판 홀로라 RR 에 든다 —
    /// 문서의 RR 설명이 「한 세대를 대표하는 간판 2점몬」이다.
    static let diamondPearlRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 6000), (.doubleRare, 3720), (.superRare, 180), (.ultraRare, 100),
    ]

    /// Black & White·XY (2011~2016). EX 와 풀아트가 자리 잡은 시대다.
    ///
    /// **BREAK 와 ACE 를 뗀다.** BREAK 는 XY 후기의 홀로 자리를 나눠 쓰던 카드라 RR 에서
    /// 떼고, ACE SPEC 은 규칙상 덱에 한 장뿐인 카드라 RRR 에서 뗀다.
    static let blackWhiteRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 5900), (.doubleRare, 3200), (.tripleRare, 140),
        (.aceSpec, 60), (.superRare, 550), (.ultraRare, 150),
    ]

    /// Sun & Moon (2017~2019). GX 와 시크릿이 가장 두꺼웠던 시대다.
    ///
    /// **레인보우(HR)를 금색(UR)에서 뗀다.** 커뮤니티는 이 둘을 확실히 구분하고, 이 시대에는
    /// 레인보우가 금색보다 흔했다.
    static let sunMoonRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 5540), (.doubleRare, 3300), (.tripleRare, 100), (.prismStar, 100),
        (.superRare, 600), (.shining, 60), (.hyperRare, 200), (.ultraRare, 100),
    ]

    /// Sword & Shield — **실측값**이다.
    ///
    /// 표본 개봉에서 V 10.56%, VMAX 5.60%, 풀아트 2.78%, 레인보우 0.84% 가 나왔다.
    /// V 는 홀로레어와 같은 RR 칸이므로 홀로레어 몫(22%)과 합쳐 적는다.
    /// 실측 0.84% 는 **레인보우**를 잰 값이므로 그대로 HR 에 둔다. 금색 시크릿(UR)은 따로
    /// 세던 값이 아니라 레어 몫에서 뗐다 — 실측한 숫자를 나눠 쓰면 그 숫자가 거짓이 된다.
    static let swordShieldRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 5794), (.doubleRare, 3256), (.tripleRare, 560),
        (.superRare, 278), (.hyperRare, 84), (.ultraRare, 28),
    ]

    /// Scarlet & Violet — **실측값**이다(676팩 표본).
    ///
    /// 레어 78.85%, 더블레어 14.05%, 울트라레어 6.51%. 남는 0.59% 가 ACE SPEC 이다.
    /// 이 칸에는 일러스트레어·스페셜아트레어·하이퍼레어가 없다 — 그쪽은 역홀로 칸이다.
    /// 남는 0.59% 는 ACE SPEC 이다 — 이 시대 RRR 자리를 쓰는 것이 그것뿐이다.
    /// **실측 세 값은 그대로 둔다.** 샤이니는 역홀로 칸에서 나온다.
    static let scarletVioletRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 7885), (.doubleRare, 1405), (.aceSpec, 59), (.superRare, 651),
    ]

    // MARK: 시대별 구성

    /// 시대별 칸 구성. 위에서 아래 순서로 뽑고 **레어 칸이 언제나 마지막**이다 —
    /// 개봉 연출이 마지막 장을 가장 좋은 장으로 놓고 움직인다.
    ///
    /// Sun & Moon 부터 실물 팩에는 기본 에너지가 한 장 고정으로 들어가지만, 그 시대 세트는
    /// 기본 에너지가 세트 목록에 없어 칸을 만들 수가 없다. 장수를 맞추려고 커먼 칸으로 센다.
    static func slotTables(_ era: PackEra)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        switch era {
        case .wotc:
            return [(commonWeights, 7), (uncommonWeights, 3), (wotcRare, 1)]
        case .ex:
            return [(commonWeights, 4), (uncommonWeights, 3), (exReverse, 1), (exRare, 1)]
        case .diamondPearl:
            return [(commonWeights, 5), (uncommonWeights, 3),
                    (diamondPearlReverse, 1), (diamondPearlRare, 1)]
        case .blackWhite:
            return [(commonWeights, 5), (uncommonWeights, 3),
                    (blackWhiteReverse, 1), (blackWhiteRare, 1)]
        case .sunMoon:
            return [(commonWeights, 5), (uncommonWeights, 3),
                    (sunMoonReverse, 1), (sunMoonRare, 1)]
        case .swordShield:
            return [(commonWeights, 5), (uncommonWeights, 3),
                    (swordShieldReverse, 1), (swordShieldRare, 1)]
        case .scarletViolet:
            return [(commonWeights, 5), (uncommonWeights, 3),
                    (scarletVioletReverse, 1), (scarletVioletRare, 1)]
        }
    }

    /// 그 시대 레어 칸의 표. 마지막 칸이 곧 레어 칸이다.
    static func rareWeights(_ era: PackEra) -> [(tier: CardTier, weight: Int)] {
        slotTables(era).last?.weights ?? scarletVioletRare
    }

    /// 팩 장수. 칸 구성에서 나온다 — 따로 적으면 둘이 갈라진다.
    static func cardsPerPack(_ era: PackEra) -> Int {
        slotTables(era).reduce(0) { $0 + $1.count }
    }

    /// 가장 긴 팩(11장, 1999년). 개봉 결과 격자가 몇 줄까지 감당해야 하는지가 여기서 나온다.
    static let maxCardsPerPack = PackEra.allCases.map { cardsPerPack($0) }.max() ?? 10

    /// 레어 이상 칸 수. 어느 시대든 한 칸이고, 도감 혜택으로 늘어나지 않는다.
    static let hitSlots = 1

    /// 사용 한도를 다 채웠을 때 주는 팩 수. 한도를 채우는 건 하루를 꼬박 쓴 것이라
    /// 한 개로는 보상이 되지 않는다.
    static let bonusPackCount = 10

    /// 특별 세트의 팩 장수. common 계층이 없는 세트를 말한다.
    ///
    /// 25장짜리 기념 세트처럼 전부 rare 이상으로 구성된 세트가 있다. 실제 카드 게임에서도
    /// 이런 세트의 팩은 4장이다.
    static let specialPackSize = 4

    /// 특별 세트의 계층 가중치. 전 슬롯을 이 가중치로 뽑아 팩 안에 등급 차이를 만든다.
    static let specialWeights: [(tier: CardTier, weight: Int)] = [
        (.rare, 4160), (.doubleRare, 3100), (.tripleRare, 500), (.prismStar, 80),
        (.amazing, 60), (.radiant, 80), (.characterRare, 20), (.artRare, 650),
        (.aceSpec, 90), (.superRare, 470), (.shiny, 70), (.shinyUltra, 20),
        (.specialArtRare, 230), (.shining, 60), (.hyperRare, 190), (.ultraRare, 180),
        (.blackWhiteRare, 10), (.megaAttack, 10), (.megaUltraRare, 10), (.futureUltra, 10),
    ]

    /// 레어 이상 칸 수. 도감 혜택으로 늘어나지 않는다 — 팩 장수를 바꾸는 혜택은 없앴다.
    static func hitSlotCount(_ perks: DexPerks) -> Int { hitSlots }

    /// 특별 팩의 장수. 전 슬롯이 가중 추첨이라 혜택은 장수를 늘리는 것으로 나타난다.
    static func specialPackSize(_ perks: DexPerks) -> Int { specialPackSize }

    /// 갓팩 — 이 확률로 팩 전체가 레어 이상이 된다. `1/godPackOneIn`.
    ///
    /// **실물에는 없는 것이다.** 실물 팩 구조를 그대로 쓰되 이것만 얹어 둔다 — 포켓몬 TCG
    /// 포켓이 0.05%(1/2000)로 넣고 있고, 이 앱은 하루 스무 팩 남짓이라 1/2000 이면 백 일에
    /// 한 번이라 있는 줄도 모르는 기능이 된다. 상점에 확률을 함께 적는다.
    static let godPackOneIn = 300

    /// 갓팩의 등급 가중치. 하한만 올리는 것이 아니라 **상한 쪽도 함께 올린다** —
    /// 포켓몬 TCG 포켓도 갓팩에서 최상위 등급 확률을 0.05% 에서 5% 로 끌어올린다.
    /// 전 칸이 레어 이상이면서 위쪽이 두꺼워야 "터졌다" 는 느낌이 난다.
    static let godWeights: [(tier: CardTier, weight: Int)] = [
        (.rare, 1840), (.doubleRare, 2970), (.tripleRare, 700), (.prismStar, 150),
        (.amazing, 120), (.radiant, 250), (.characterRare, 30), (.artRare, 1100),
        (.aceSpec, 250), (.superRare, 950), (.shiny, 180), (.shinyUltra, 70),
        (.specialArtRare, 400), (.shining, 150), (.hyperRare, 350), (.ultraRare, 300),
        (.blackWhiteRare, 80), (.megaAttack, 15), (.megaUltraRare, 80), (.futureUltra, 15),
    ]

    /// 천장 — 레어 이상 칸에서 이 횟수만큼 연속으로 레어만 나오면 다음은 RR 이상을 보장한다.
    ///
    /// SV 실측 기준으로 레어 칸의 79% 가 그냥 레어라, 다섯 번 연속 레어만 나올 확률이 31% 다.
    /// 흔하게 일어나는 만큼 상한을 두고 그 숫자를 상점에 함께 적는다 — 보장을 두고 숨기면
    /// 그것대로 공시 의무를 어긴다.
    static let pityThreshold = 5

    /// 가중치에 혜택을 반영한다.
    ///
    /// `hitOdds` 는 레어의 몫을 덜어 **레어보다 위 등급에만** 나눠 준다. 커먼·언커먼까지
    /// 같이 오르면 일반 칸에서는 오히려 나빠진다. 커먼 칸과 언커먼 칸에는 레어가 없으므로
    /// 이 계산이 그대로 지나가고, 실제로 걸리는 곳은 역홀로 칸과 레어 칸이다.
    /// 정수 가중치의 반올림 손실을 막으려고 100 배로 올려 계산한다.
    static func weights(_ base: [(tier: CardTier, weight: Int)],
                        perks: DexPerks) -> [(tier: CardTier, weight: Int)] {
        let scaled = base.map { (tier: $0.tier, weight: $0.weight * 100) }
        guard perks.hitOdds > 0 else { return scaled }

        let rareRank = CardTier.rare.rank
        let above = scaled.filter { $0.tier.rank > rareRank }
        let aboveTotal = above.reduce(0) { $0 + $1.weight }
        guard let rare = scaled.first(where: { $0.tier == .rare }), aboveTotal > 0 else {
            return scaled
        }
        let moved = Double(rare.weight) * perks.hitOdds
        return scaled.map { entry in
            if entry.tier == .rare {
                return (tier: entry.tier, weight: max(1, Int((Double(entry.weight) - moved).rounded())))
            }
            guard entry.tier.rank > rareRank else { return entry }
            let share = moved * Double(entry.weight) / Double(aboveTotal)
            return (tier: entry.tier, weight: Int((Double(entry.weight) + share).rounded()))
        }
    }
}

/// 팩 한 칸의 공시. 몇 장이 어떤 등급으로 나오는지 그대로 적는다.
///
/// 평균 하나로 뭉뚱그리면 "UR 0.11%" 가 열 장 각각의 확률처럼 읽힌다. 실제로는 아홉 칸이
/// UR 을 뽑을 수 없고 한 칸만 굴린다. 그 구조를 그대로 보여 주는 것이 정확하다
/// (포켓몬 TCG 포켓도 칸별로 공시하고, 게임산업법도 구성 비율과 산정 기준을 요구한다).
struct PackSlot: Equatable, Sendable, Identifiable {
    /// 표시 순서 겸 식별자.
    let id: Int
    /// 이 칸이 몇 장인가.
    let count: Int
    /// 확정 칸이면 그 등급. 추첨 칸이면 nil.
    let guaranteed: CardTier?
    /// 추첨 칸의 등급별 확률. 합은 1 이다.
    let odds: [PackOpening.TierOdds]
}

/// 팩 가격. 세트마다 표를 두지 않고 구성에서 유도한다 — 세트를 추가할 때 가격을 잊지 않게.
enum PackPricing {

    /// 팩 하나의 값. **세트마다 다르다.**
    ///
    /// 예전에는 일반 팩 1,000만·특별 팩 2,000만으로 두 종류뿐이었다. 실제로는 세트에 따라
    /// 팩 안의 기대 시세가 50배 넘게 갈리므로, 같은 값에 팔면 제일 비싼 세트만 사는 것이
    /// 유일한 정답이 된다.
    ///
    /// 시세를 못 읽으면 예전 고정값으로 물러난다 — 값이 0 인 상점이 되는 것보다 낫다.
    static func price(setID: String, index: CardIndex,
                      prices: CardPrices? = CardPrices.shared,
                      perks: DexPerks = .none) -> Int {
        let base = basePrice(setID: setID, index: index, prices: prices)
        guard perks.packDiscount > 0 else { return base }
        // 할인을 곱하면 100원 칸에서 벗어난다. 곱한 뒤에 다시 끊는다.
        return MarketEconomy.quantized(Int((Double(base) * (1 - perks.packDiscount)).rounded()),
                                       prices: prices)
    }

    /// 혜택을 빼고 본 팩값.
    static func basePrice(setID: String, index: CardIndex, prices: CardPrices?) -> Int {
        let value = MarketEconomy.packValueUSD(setID: setID, index: index, prices: prices)
        guard value > 0 else { return fallbackPrice(setID: setID, index: index) }
        return MarketEconomy.tokens(usd: value * MarketEconomy.packMargin)
    }

    /// 시세가 없을 때의 예전 고정값.
    static func fallbackPrice(setID: String, index: CardIndex) -> Int {
        (index.pools[setID]?[.common] ?? []).isEmpty ? 20_000_000 : 10_000_000
    }

    static func cardCount(setID: String, index: CardIndex, perks: DexPerks = .none) -> Int {
        let pool = index.pools[setID] ?? [:]
        return (pool[.common] ?? []).isEmpty
            ? PackConfig.specialPackSize(perks)
            : PackConfig.cardsPerPack(index.era(setID))
    }
}

/// 중복 카드를 팔았을 때 받는 돈. **그 카드의 시세를 그대로 준다.**
///
/// 화면에 "이 카드 12,000원" 이라 적어 두고 팔 때 그보다 적게 주면 적어 둔 값이 무엇을
/// 뜻하는지 알 수 없게 된다. 판매가는 시세와 같고, 도감 혜택이 있으면 그 위에 추가금이 붙는다.
///
/// 등급표를 쓰지 않는다. 같은 SAR 이라도 리자몽과 나머지가 시장에서 25배 차이 나고,
/// 등급 사다리 자체가 시장과 네 군데에서 순서가 뒤집혀 있다.
///
/// 팩 하나를 통째로 팔아 나오는 총액이 팩 값을 넘으면 안 된다 — 사서 팔기만 반복하는 것이
/// 이득이면 게임이 성립하지 않는다. 팩값이 같은 시세에 `MarketEconomy.packMargin` 을 곱한
/// 값이므로 이 비율은 자동으로 `1/packMargin` 에서 시작한다.
enum CardSale {
    /// 한 장 값. `perks.dustBonus` 가 도감이 주는 판매 추가금이다.
    static func price(cardID: String, prices: CardPrices? = CardPrices.shared,
                      perks: DexPerks = .none) -> Int {
        let base = MarketEconomy.tokens(usd: MarketEconomy.usd(cardID: cardID, prices: prices),
                                        prices: prices)
        guard perks.dustBonus > 0 else { return base }
        // 추가금을 곱하면 100원 칸에서 벗어난다. 곱한 뒤에 다시 끊는다.
        return MarketEconomy.quantized(Int((Double(base) * (1 + perks.dustBonus)).rounded()),
                                       prices: prices)
    }
}

/// 팩 개봉 결과. 카드와 함께 이 팩이 갓팩이었는지 알려 준다.
struct OpenedCards: Equatable, Sendable {
    let cards: [PulledCard]
    /// 전 칸이 레어 이상으로 나온 팩. 개봉 연출이 이걸 보고 다르게 움직인다.
    let isGodPack: Bool

    static let empty = OpenedCards(cards: [], isGodPack: false)
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
    /// 천장을 세지 않는 호출. 확률 분포를 확인하는 검증 코드용이다 —
    /// 실제 개봉은 반드시 천장을 세는 쪽을 써야 보장이 성립한다(`DexPerkRoutingTests` 가 잠근다).
    static func draw(
        setID: String,
        index: CardIndex,
        alreadyOwned: Set<String>,
        perks: DexPerks = .none,
        using generator: inout some RandomNumberGenerator
    ) -> [PulledCard] {
        var ignored = 0
        return draw(setID: setID, index: index, alreadyOwned: alreadyOwned, perks: perks,
                    pity: &ignored, using: &generator).cards
    }

    /// - Parameter pity: 레어 이상 칸에서 연속으로 레어만 나온 횟수. 이 값이 상한에 닿으면
    ///   다음 팩은 RR 이상을 보장하고, 보장이 발동하거나 자연히 RR 이상이 나오면 0 으로 돌아간다.
    ///   세트별로 따로 센다 — 세트를 바꿔 사며 천장을 모으는 것을 막는다.
    static func draw(
        setID: String,
        index: CardIndex,
        alreadyOwned: Set<String>,
        perks: DexPerks = .none,
        pity: inout Int,
        using generator: inout some RandomNumberGenerator
    ) -> OpenedCards {
        guard let pool = index.pools[setID], !pool.isEmpty else { return .empty }

        // common 이 없는 세트는 일반 팩 구성을 쓸 수 없다. 전 슬롯을 가중 추첨한다.
        if (pool[.common] ?? []).isEmpty {
            var picked: [PulledCard] = []
            var used: Set<String> = []
            for _ in 0..<PackConfig.specialPackSize(perks) {
                let tier = weightedTier(PackConfig.weights(PackConfig.specialWeights, perks: perks),
                                        available: pool, using: &generator)
                guard let id = pick(tier: tier, from: pool, avoiding: used, using: &generator) else { continue }
                used.insert(id)
                picked.append(PulledCard(id: id, tier: index.card(id)?.tier ?? tier,
                                         isNew: !alreadyOwned.contains(id)))
            }
            // 특별 세트는 원래 전 칸이 레어 이상이라 갓팩 개념이 없다.
            return OpenedCards(cards: picked, isGodPack: false)
        }

        // 갓팩 판정을 먼저 한다. 걸리면 전 칸이 갓팩 표에서 나온다.
        let era = index.era(setID)
        let isGod = generator.next(upperBound: UInt64(PackConfig.godPackOneIn)) == 0
        var requests: [CardTier] = []

        if isGod {
            let weights = PackConfig.weights(PackConfig.godWeights, perks: perks)
            for _ in 0..<PackPricing.cardCount(setID: setID, index: index, perks: perks) {
                requests.append(weightedTier(weights, available: pool, using: &generator))
            }
            // 갓팩은 레어 이상만 나오므로 천장을 다시 채울 이유가 없다.
            pity = 0
        } else {
            // 그 시대의 칸 구성을 그대로 따라간다. 레어 칸만 따로 다루므로 마지막을 뺀다.
            for (weights, count) in Self.standardSlotTables(era: era, perks: perks).dropLast() {
                for _ in 0..<count {
                    requests.append(weightedTier(weights, available: pool, using: &generator))
                }
            }

            // 마지막 칸은 레어 이상만 뽑는다. 천장이 걸려 있으면 RR 이상으로 올린다.
            for _ in 0..<PackConfig.hitSlotCount(perks) {
                requests.append(hitTier(available: pool, era: era, perks: perks,
                                        pity: pity, using: &generator))
            }
            pity = Self.nextPity(after: requests.suffix(PackConfig.hitSlotCount(perks)), from: pity)
        }

        var picked: [PulledCard] = []
        var usedInThisPack: Set<String> = []
        // 중복이 나와도 다시 뽑지 않는다. 값비싼 카드가 떴는데 「이미 가진 것」이라는 이유로
        // 더 싼 카드로 바뀌면, 도와주려던 장치가 오히려 뽑기를 망친 것으로 남는다.
        for tier in requests {
            guard let id = pick(tier: tier, from: pool, avoiding: usedInThisPack,
                                using: &generator) else { continue }
            usedInThisPack.insert(id)
            let actualTier = index.card(id)?.tier ?? tier
            picked.append(PulledCard(id: id, tier: actualTier, isNew: !alreadyOwned.contains(id)))
        }
        return OpenedCards(cards: picked, isGodPack: isGod)
    }

    /// 카드 한 장이 각 등급일 확률. 모든 등급을 더하면 1 이다.
    ///
    /// "팩에 한 장 이상 들어올 확률" 로 매기면 고정 슬롯 등급이 전부 100% 가 되어
    /// 등급 사이의 비중을 읽을 수 없다. 한 장 기준이면 커먼 60% · UR 0.1% 처럼
    /// 서로 견줄 수 있는 하나의 축에 놓인다.
    ///
    /// 뽑기가 만드는 슬롯 구성을 그대로 따라가며 센다. 폴백까지 반영하므로
    /// 표시한 값과 실제 결과가 갈라지지 않는다.
    struct TierOdds: Equatable {
        let tier: CardTier
        /// 카드 한 장이 이 등급일 확률 (0~1).
        let probability: Double
    }

    static func packOdds(setID: String, index: CardIndex, perks: DexPerks = .none) -> [TierOdds] {
        let pool = index.pools[setID] ?? [:]
        guard !pool.isEmpty else { return [] }

        var expected: [CardTier: Double] = [:]

        func addWeighted(_ weights: [(tier: CardTier, weight: Int)], slots: Double) {
            let available = weights.filter { !(pool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0, slots > 0 else { return }
            for entry in available {
                let p = Double(entry.weight) / Double(total)
                expected[entry.tier, default: 0] += p * slots
            }
        }

        if (pool[.common] ?? []).isEmpty {
            // 특별 세트 — 전 슬롯이 가중 추첨이다.
            addWeighted(PackConfig.weights(PackConfig.specialWeights, perks: perks),
                        slots: Double(PackConfig.specialPackSize(perks)))
        } else {
            // 갓팩을 섞는다. 표시된 확률이 실제 결과와 갈라지지 않으려면 여기에도 들어가야 한다.
            // 도감 난이도도 이 값에서 나오므로 빼먹으면 난이도가 조용히 어긋난다.
            let godChance = 1.0 / Double(PackConfig.godPackOneIn)
            let cards = PackPricing.cardCount(setID: setID, index: index, perks: perks)
            for (weights, count) in Self.standardSlotTables(era: index.era(setID), perks: perks) {
                addWeighted(weights, slots: Double(count) * (1 - godChance))
            }
            addWeighted(PackConfig.weights(PackConfig.godWeights, perks: perks),
                        slots: Double(cards) * godChance)
        }

        let cardsPerPack = expected.values.reduce(0, +)
        guard cardsPerPack > 0 else { return [] }
        return expected.keys
            .map { TierOdds(tier: $0, probability: (expected[$0] ?? 0) / cardsPerPack) }
            .sorted { $0.tier.rank > $1.tier.rank }
    }

    /// 그 시대 팩의 칸 표. 뽑기·기대 구성·공시가 모두 이 하나를 본다 —
    /// 세 곳에 따로 적으면 표시된 확률과 실제 결과가 갈라진다.
    static func standardSlotTables(era: PackEra, perks: DexPerks)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        PackConfig.slotTables(era).map {
            (weights: PackConfig.weights($0.weights, perks: perks), count: $0.count)
        }
    }

    /// 칸별 공시. 상점이 이 값을 그대로 표로 그린다.
    static func packSlots(setID: String, index: CardIndex, perks: DexPerks = .none) -> [PackSlot] {
        let pool = index.pools[setID] ?? [:]
        guard !pool.isEmpty else { return [] }

        func odds(_ weights: [(tier: CardTier, weight: Int)]) -> [TierOdds] {
            let available = weights.filter { !(pool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0 else { return [] }
            return available
                .map { TierOdds(tier: $0.tier, probability: Double($0.weight) / Double(total)) }
                .sorted { $0.tier.rank > $1.tier.rank }
        }

        if (pool[.common] ?? []).isEmpty {
            let weights = PackConfig.weights(PackConfig.specialWeights, perks: perks)
            return [PackSlot(id: 0, count: PackConfig.specialPackSize(perks),
                             guaranteed: nil, odds: odds(weights))]
        }
        return Self.standardSlotTables(era: index.era(setID), perks: perks)
            .enumerated().map { offset, table in
            PackSlot(id: offset, count: table.count, guaranteed: nil, odds: odds(table.weights))
        }
    }

    /// 히트 슬롯만의 등급 분포. 뽑기 내부와 상세 표시가 같은 값을 쓰도록 남겨 둔다.
    static func hitOdds(setID: String, index: CardIndex) -> [(tier: CardTier, probability: Double)] {
        let pool = index.pools[setID] ?? [:]
        let weights = (pool[.common] ?? []).isEmpty
            ? PackConfig.specialWeights
            : PackConfig.rareWeights(index.era(setID))
        let available = weights.filter { !(pool[$0.tier] ?? []).isEmpty }
        let total = available.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }
        return available
            .map { (tier: $0.tier, probability: Double($0.weight) / Double(total)) }
            .sorted { $0.tier.rank > $1.tier.rank }
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
        era: PackEra = .scarletViolet,
        perks: DexPerks = .none,
        pity: Int = 0,
        using generator: inout some RandomNumberGenerator
    ) -> CardTier {
        var weights = PackConfig.weights(PackConfig.rareWeights(era), perks: perks)
        // 천장 — 레어를 후보에서 빼 RR 이상만 남긴다. 세트에 RR 이상이 없으면
        // (1999년 세트 중 일부) 빼지 않는다. 뺐다가 후보가 비면 슬롯이 사라진다.
        if pity >= PackConfig.pityThreshold {
            let above = weights.filter { $0.tier != .rare && !(pool[$0.tier] ?? []).isEmpty }
            if !above.isEmpty { weights = above }
        }
        return weightedTier(weights, available: pool, using: &generator)
    }

    /// 다음 팩에 넘길 천장 카운터. RR 이상이 하나라도 나왔으면 0 으로 돌아간다.
    static func nextPity(after hits: some Collection<CardTier>, from current: Int) -> Int {
        var value = current
        for tier in hits {
            value = tier.rank > CardTier.rare.rank ? 0 : value + 1
        }
        return value
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
