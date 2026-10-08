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

    /// 현대 팩의 커먼 칸. 기본 에너지는 별도 고정 카드이므로 이 풀에 섞지 않는다.
    static let commonWeights: [(tier: CardTier, weight: Int)] = [(.common, 10000)]

    /// 확정 기본 에너지 칸. Base·Base Set 2는 두 장, Gym과 Neo Genesis는
    /// 한 장을 이 표에서 뽑는다.
    static let energyWeights: [(tier: CardTier, weight: Int)] = [(.energy, 10000)]

    /// 기본 에너지가 커먼 자리를 차지하던 WotC·초기 e-Card/EX 팩의 커먼 칸.
    /// 에너지 카드가 없는 세트에서는 `weightedTier` 가 후보에서 에너지를 빼고 재정규화한다.
    static let legacyCommonWeights: [(tier: CardTier, weight: Int)] = [
        (.common, 8600), (.energy, 1400),
    ]

    /// 언커먼 칸.
    static let uncommonWeights: [(tier: CardTier, weight: Int)] = [(.uncommon, 10000)]

    // MARK: 칸 표 — 역홀로

    /// e-Card와 EX1–EX4의 역홀로 칸. 이 구간은 Holo Rare를 역홀로 평행판으로
    /// 싣지 않았으므로 RR을 절대 후보로 만들지 않는다.
    static let legacyEXReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5500), (.uncommon, 3500), (.rare, 1000),
    ]

    /// EX5–EX16 전체 체크리스트의 합산 fallback. 실제 세트 경로는 아래의
    /// `exReverseWeights(setID:)` 로 각 세트의 카드 장수를 사용한다.
    static let exReverse: [(tier: CardTier, weight: Int)] = [
        // 378 C / 387 U / 214 R / 196 Rare Holo across all twelve sets.
        (.common, 3217), (.uncommon, 3294), (.rare, 1821), (.doubleRare, 1668),
    ]

    /// EX5–EX16 reverse checklists include ordinary Rare Holo printings but
    /// never Pokemon-ex. With no surviving official sheet ratios, every listed
    /// reverse printing is modelled as equally likely inside its own set.
    static func exReverseWeights(setID: String) -> [(tier: CardTier, weight: Int)] {
        switch setID {
        case "ex5":  [(.common, 32), (.uncommon, 33), (.rare, 12), (.doubleRare, 15)]
        case "ex6":  [(.common, 36), (.uncommon, 36), (.rare, 14), (.doubleRare, 17)]
        case "ex7":  [(.common, 32), (.uncommon, 35), (.rare, 14), (.doubleRare, 14)]
        case "ex8":  [(.common, 32), (.uncommon, 34), (.rare, 14), (.doubleRare, 15)]
        case "ex9":  [(.common, 32), (.uncommon, 32), (.rare, 14), (.doubleRare, 17)]
        case "ex10": [(.common, 31), (.uncommon, 34), (.rare, 44), (.doubleRare, 19)]
        case "ex11": [(.common, 34), (.uncommon, 35), (.rare, 20), (.doubleRare, 18)]
        case "ex12": [(.common, 27), (.uncommon, 26), (.rare, 15), (.doubleRare, 14)]
        case "ex13": [(.common, 31), (.uncommon, 30), (.rare, 20), (.doubleRare, 23)]
        case "ex14": [(.common, 29), (.uncommon, 30), (.rare, 16), (.doubleRare, 13)]
        case "ex15": [(.common, 30), (.uncommon, 31), (.rare, 16), (.doubleRare, 12)]
        case "ex16": [(.common, 32), (.uncommon, 31), (.rare, 15), (.doubleRare, 19)]
        default: exReverse
        }
    }

    static let diamondPearlReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5500), (.uncommon, 3400), (.rare, 1100),
    ]

    static let blackWhiteReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 5400), (.uncommon, 3400), (.rare, 1200),
    ]

    /// Double Crisis의 역홀로 체크리스트는 14 C + 12 U + 6 Holo Rare다.
    /// 카드별 동일 비중의 최소 모델이며 두 full art는 이 칸에 들어오지 않는다.
    static let doubleCrisisReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4_375), (.uncommon, 3_750), (.doubleRare, 1_875),
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

    // MARK: Special-subset replacement positions

    /// Hidden Fates Shiny Vault, measured from a large community sample.
    /// Shiny Rare (21.2%), Shiny GX (10.19%), full-art Trainer (3.42%), and gold
    /// (1.01%) all replace the reverse-holo card; the latter three share SSR in
    /// the simulator while their original rarity still controls their finish.
    static let hiddenFatesReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 3402), (.uncommon, 2182), (.rare, 834),
        (.shiny, 2120), (.shinyUltra, 1462),
    ]

    /// Shining Fates, measured from 1,087 packs. Baby shiny is 1/4, Shiny V is
    /// 1/14, Shiny VMAX is 1/39, gold is 0.65%, and Amazing Rare is 1/19.
    static let shiningFatesReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 3119), (.uncommon, 1980), (.rare, 840),
        (.amazing, 526), (.shiny, 2500), (.shinyUltra, 1035),
    ]

    /// TCGplayer mass-opening estimates. Trainer Gallery replaces the reverse
    /// holo independently of the pack's rare position.
    static let brilliantStarsReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4304), (.uncommon, 2731), (.rare, 1159), (.characterRare, 1806),
    ]
    static let astralRadianceReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4328), (.uncommon, 2747), (.rare, 1166),
        (.radiant, 501), (.characterRare, 1258),
    ]
    static let lostOriginReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4342), (.uncommon, 2756), (.rare, 1170),
        (.radiant, 501), (.characterRare, 1231),
    ]
    static let silverTempestReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 4369), (.uncommon, 2774), (.rare, 1179),
        (.radiant, 455), (.characterRare, 1223),
    ]

    /// Crown Zenith's Galarian Gallery also replaces the reverse-holo card.
    /// TCGplayer's sample measured about 22.2% yellow-border art, 12.1% silver
    /// art, and 0.6% gold; the latter two share SAR while rarity retains gold foil.
    static let crownZenithReverse: [(tier: CardTier, weight: Int)] = [
        (.common, 3180), (.uncommon, 2018), (.rare, 857),
        (.radiant, 455), (.artRare, 2220), (.specialArtRare, 1270),
    ]

    /// Celebrations has four foil cards. The first two are ordinary main-set
    /// holos, Classic Collection can replace position three (about 40% in a
    /// 5,000-pack sample), and the main-set hit is position four.
    static let celebrationsHolo: [(tier: CardTier, weight: Int)] = [
        (.rare, 10_000),
    ]
    static let celebrationsRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 4800), (.doubleRare, 4000), (.tripleRare, 800), (.superRare, 400),
    ]
    static let celebrationsClassicPosition: [(tier: CardTier, weight: Int)] = [
        (.rare, 6000), (.characterRare, 4000),
    ]

    /// Generations' second Radiant Collection sheet is reconstructed from the
    /// surviving 10x10 uncut sheet: 12 Uncommons six times each, plus seven
    /// Ultra Rares four times each (72:28). The compact index retains the source
    /// rarity, so the seven Ultra Rares span RR and SR here.
    static let generationsRadiantHigh: [(tier: CardTier, weight: Int)] = [
        (.uncommon, 7200), (.doubleRare, 800), (.superRare, 2000),
    ]

    /// Legendary Treasures' high RC sheet is modelled as 70% Uncommon and 30%
    /// Ultra Rare. RC11 is the regular Meloetta-EX rather than a full art, so
    /// its upstream tier remains R while the other five are SR.
    static let legendaryTreasuresRadiantHigh: [(tier: CardTier, weight: Int)] = [
        (.uncommon, 7000), (.rare, 500), (.superRare, 2500),
    ]

    /// Legendary Treasures puts a base-set Holo Rare in the reverse position
    /// half the time. The other half remains a C/U/R reverse parallel.
    static let legendaryTreasuresReverseOrHolo: [(tier: CardTier, weight: Int)] = [
        (.common, 2700), (.uncommon, 1700), (.rare, 600), (.doubleRare, 5000),
    ]

    /// Six Pokémon-EX per 36-pack box and one secret rare per three boxes;
    /// every remaining rare position is a non-holo Rare.
    static let legendaryTreasuresRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 8241), (.doubleRare, 1667), (.ultraRare, 92),
    ]

    /// Generations sample model: 3.8 holos + 7.4 Pokémon-EX + 0.8 full arts
    /// per 36 packs, with the remaining 24 positions non-holo Rare.
    static let generationsRare: [(tier: CardTier, weight: Int)] = [
        (.rare, 6667), (.doubleRare, 3111), (.superRare, 222),
    ]

    /// Scarlet & Violet — **실측값**이다.
    ///
    /// 일러스트레어 7.69%, 스페셜아트레어 3.11%, 하이퍼레어 1.92% 가 이 칸에서 나온다.
    /// SV 의 상위 등급이 레어 칸이 아니라 역홀로 칸에서 나온다는 것이 이 시대의 핵심이고,
    /// 그래서 "레어 칸 확률" 만 적으면 실제와 어긋난다. 남는 87.28% 는 커먼·언커먼·레어의
    /// 역홀로이며 세트의 장수 비율(대략 56:32:12)로 나눴다.
    /// 샤이니(S)도 이 칸이다 — 「팔데아의 운명」처럼 이로치가 주력인 세트에서 역홀로
    /// 자리를 대신 차지한다. 실측한 세 값(AR·SAR·UR)은 건드리지 않고 유도값인 커먼 몫에서 뗐다.
    /// 첫 번째 역홀로 칸. 이 칸은 평행 인쇄 C/U/R 만 담는다.
    static let scarletVioletReverseBase: [(tier: CardTier, weight: Int)] = [
        (.common, 5600), (.uncommon, 3200), (.rare, 1200),
    ]

    /// 두 번째 역홀로 칸. 상위 히트가 이 자리만 대체한다.
    /// 이름은 기존 확률·가격 호출부 호환을 위해 유지한다.
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

    /// 시대별 표준 칸 구성. 물리 팩 메타데이터와 칸 수는 `PackRecipe` 가 단일 출처다.
    static func slotTables(_ era: PackEra)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        slotTables(recipe: PackRecipe.standard(for: era), setID: nil, era: era)
    }

    /// 세트 전용 레시피를 반영한 칸 구성. Celebrations처럼 시대 표준과 다른 팩도 여기로 온다.
    static func slotTables(setID: String, era: PackEra)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        slotTables(recipe: PackRecipe.forSet(setID, era: era), setID: setID, era: era)
    }

    private static func slotTables(recipe: PackRecipe, setID: String?, era: PackEra)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        recipe.slots.map { slot in
            // 세트별 실측값이 있으면 시대 표보다 앞선다.
            if let setID, let measured = PackOdds.weights(setID: setID, slot: slot.kind) {
                return (weights: measured, count: slot.count)
            }
            let weights: [(tier: CardTier, weight: Int)]
            switch slot.kind {
            case .energy:
                weights = energyWeights
            case .common:
                // Wizards Energy cards occupy explicit fixed slots above. The
                // legacy mixture remains only for early e-Card/EX collation.
                weights = era == .ex ? legacyCommonWeights : commonWeights
            case .uncommon:
                weights = uncommonWeights
            case .reverseHolo:
                switch setID {
                case "dc1": weights = doubleCrisisReverse
                case "sm115": weights = hiddenFatesReverse
                case "swsh45": weights = shiningFatesReverse
                case "swsh9": weights = brilliantStarsReverse
                case "swsh10": weights = astralRadianceReverse
                case "swsh11": weights = lostOriginReverse
                case "swsh12": weights = silverTempestReverse
                case "swsh12pt5": weights = crownZenithReverse
                default:
                    switch era {
                    case .wotc: weights = commonWeights
                    case .ex:
                        if let setID,
                           usesEX5To16ReverseChecklist(setID: setID) {
                            weights = exReverseWeights(setID: setID)
                        } else {
                            weights = legacyEXReverse
                        }
                    case .diamondPearl: weights = diamondPearlReverse
                    case .blackWhite: weights = blackWhiteReverse
                    case .sunMoon: weights = sunMoonReverse
                    case .swordShield: weights = swordShieldReverse
                    case .scarletViolet: weights = scarletVioletReverseBase
                    }
                }
            case .reverseHoloHit:
                // New Mega Attack printings must remain reachable. This is a
                // simulator estimate, not a published Ascended Heroes pull rate.
                weights = setID == "me2pt5"
                    ? scarletVioletReverse.map { ($0.tier, $0.tier == .common ? $0.weight - 167 : $0.weight) }
                        + [(.megaAttack, 167)]
                    : scarletVioletReverse
            case .legendaryTreasuresReverse:
                weights = legendaryTreasuresReverseOrHolo
            case .rare:
                switch setID {
                case "bw11": weights = legendaryTreasuresRare
                case "g1": weights = generationsRare
                default:
                    switch era {
                    case .wotc: weights = wotcRare
                    case .ex: weights = exRare
                    case .diamondPearl: weights = diamondPearlRare
                    case .blackWhite: weights = blackWhiteRare
                    case .sunMoon: weights = sunMoonRare
                    case .swordShield: weights = swordShieldRare
                    case .scarletViolet: weights = scarletVioletRare
                    }
                }
            case .allFoil:
                weights = setID == "cel30" ? anniversaryFoilWeights : specialWeights
            case .anniversaryPikachu:
                weights = [(.artRare, 10_000)]
            case .celebrationsHolo:
                weights = celebrationsHolo
            case .classicCollection:
                weights = celebrationsClassicPosition
            case .celebrationsRare:
                weights = celebrationsRare
            case .radiantCollectionCommon:
                weights = commonWeights
            case .radiantCollectionHigh:
                weights = setID == "g1"
                    ? generationsRadiantHigh
                    : legendaryTreasuresRadiantHigh
            }
            return (weights: weights, count: slot.count)
        }
    }

    private static func usesEX5To16ReverseChecklist(setID: String) -> Bool {
        guard setID.hasPrefix("ex"),
              let number = Int(setID.dropFirst(2)) else { return false }
        return (5...16).contains(number)
    }

    /// 그 시대 레어 칸의 표. 마지막 칸이 곧 레어 칸이다.
    static func rareWeights(_ era: PackEra) -> [(tier: CardTier, weight: Int)] {
        slotTables(era).last?.weights ?? scarletVioletRare
    }

    /// 팩 장수. 칸 구성에서 나온다 — 따로 적으면 둘이 갈라진다.
    static func cardsPerPack(_ era: PackEra) -> Int {
        PackRecipe.standard(for: era).contents.gameCardCount
    }

    static func contents(setID: String, era: PackEra) -> PackContents {
        PackRecipe.forSet(setID, era: era).contents
    }

    /// 가장 긴 팩(11장, 1999년). 개봉 결과 격자가 몇 줄까지 감당해야 하는지가 여기서 나온다.
    static let maxCardsPerPack = PackEra.allCases.map { cardsPerPack($0) }.max() ?? 10

    /// 레어 이상 칸 수. 어느 시대든 한 칸이고, 도감 혜택으로 늘어나지 않는다.
    static let hitSlots = 1

    /// 사용 한도를 다 채웠을 때 주는 보상의 **값어치**. 개수가 아니라 값으로 정한다.
    ///
    /// 예전에는 세트와 무관하게 10팩이었다. 팩값이 세트마다 700배 갈리므로(271만~19.8억)
    /// 무작위로 고른 세트에 개수를 고정하면 한 번에 12.2억원이 나왔다 — 하루 사료 수입의
    /// 여섯 배가 넘는다. 값을 고정하면 어느 세트가 걸리든 보상 크기가 같고, 무작위는
    /// 「어느 세트냐」에만 남는다.
    ///
    /// 크기는 하루 수입의 10% 안팎을 목표로 잡았다. 한도는 하루 한두 번 차므로 이 정도가
    /// 사료 수입을 뒤엎지 않으면서 보상으로 읽히는 선이다.
    static let bonusBudget = 20_000_000

    /// 보너스로 한 번에 줄 수 있는 팩 수 상한. 예산이 이미 값을 묶고 있어 보통은 닿지 않는다
    /// (제일 싼 세트가 7팩). 시세를 못 읽어 팩값이 헐값으로 잡히는 경우에만 걸린다.
    static let bonusPackCap = 10

    /// Celebrations의 4-card all-foil 팩 장수. common 유무로 특별 세트를 추측하지 않는다.
    static let specialPackSize = 4

    /// Celebrations의 전 슬롯 가중치. 네 장 모두 foil이지만 카드 등급은 서로 다르다.
    static let specialWeights: [(tier: CardTier, weight: Int)] = [
        (.rare, 4160), (.doubleRare, 3100), (.tripleRare, 500), (.prismStar, 80),
        (.amazing, 60), (.radiant, 80), (.characterRare, 20), (.artRare, 650),
        (.aceSpec, 90), (.superRare, 470), (.shiny, 70), (.shinyUltra, 20),
        (.specialArtRare, 230), (.shining, 60), (.hyperRare, 190), (.ultraRare, 180),
        (.blackWhiteRare, 10), (.megaAttack, 10), (.megaUltraRare, 10), (.futureUltra, 10),
    ]

    /// 30th Celebration positions 1–2 are foil Commons. Positions 3 and 4 and their
    /// measured rates live in `pack-odds.json` like every other measured set.
    static let anniversaryFoilWeights: [(tier: CardTier, weight: Int)] = [
        (.common, 10_000),
    ]

    /// 레어 이상 칸 수. 도감 혜택으로 늘어나지 않는다 — 팩 장수를 바꾸는 혜택은 없앴다.
    static func hitSlotCount(_ perks: DexPerks) -> Int { hitSlots }

    /// 기존 호출부 호환용 Celebrations 팩 장수.
    static func specialPackSize(_ perks: DexPerks) -> Int { specialPackSize }

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

/// 팩 가격. 실제 밀봉 부스터 시장가가 있으면 그것을 쓰고, 없는 세트만 구성 기대값에서 유도한다.
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
                      marketPrices: PackMarketPrices? = PackMarketPrices.shared,
                      perks: DexPerks = .none) -> Int {
        let base = basePrice(setID: setID, index: index, prices: prices,
                             marketPrices: marketPrices)
        guard perks.packDiscount > 0 else { return base }
        // 할인을 곱하면 100원 칸에서 벗어난다. 곱한 뒤에 다시 끊는다.
        return MarketEconomy.quantized(Int((Double(base) * (1 - perks.packDiscount)).rounded()),
                                       prices: prices)
    }

    /// 혜택을 빼고 본 팩값.
    static func basePrice(setID: String, index: CardIndex, prices: CardPrices?,
                          marketPrices: PackMarketPrices? = PackMarketPrices.shared) -> Int {
        quote(setID: setID, index: index, prices: prices, marketPrices: marketPrices).baseTokens
    }

    /// 시세가 없을 때의 예전 고정값.
    static func fallbackPrice(setID: String, index: CardIndex) -> Int {
        (index.pools[setID]?[.common] ?? []).isEmpty ? 20_000_000 : 10_000_000
    }

    static func cardCount(setID: String, index: CardIndex, perks: DexPerks = .none) -> Int {
        PackRecipe.forSet(setID, era: index.era(setID)).contents.gameCardCount
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

/// A drawn card together with the physical finish implied by its pack position.
/// `PulledCard` stays source-compatible while the printing-level collection
/// model is introduced; callers can map this hint to `CardFinish` without
/// guessing from rarity.
struct PackSlotResult: Codable, Equatable, Sendable {
    let card: PulledCard
    let finishHint: PackFinishHint
}

/// 팩 개봉 결과. 카드와 함께 어떤 세트 전용 변형 팩이었는지 알려 준다.
struct OpenedCards: Codable, Equatable, Sendable {
    let slotResults: [PackSlotResult]
    let variant: PackVariant

    var cards: [PulledCard] { slotResults.map(\.card) }
    /// 기존 개봉 연출용 호환 프로퍼티. 151은 demigod이므로 God Pack으로 표시하지 않는다.
    var isGodPack: Bool { variant.isGodPack }
    var isSpecialVariant: Bool { variant.isSpecialHit }

    init(slotResults: [PackSlotResult], variant: PackVariant) {
        self.slotResults = slotResults
        self.variant = variant
    }

    /// 기존 테스트·호출부를 위한 호환 초기화. 새 코드는 variant를 직접 넘긴다.
    init(cards: [PulledCard], isGodPack: Bool) {
        self.slotResults = cards.map { PackSlotResult(card: $0, finishHint: .defaultForCard) }
        self.variant = isGodPack ? .prismaticEvolutionsGod : .standard
    }

    static let empty = OpenedCards(slotResults: [], variant: .standard)
}

/// 팩 개봉 결과 카드 1장.
struct PulledCard: Codable, Equatable, Sendable, Identifiable {
    let id: String        // 카드 ID
    let tier: CardTier
    /// 이 개봉으로 처음 얻은 카드인가. 연출에서 신규 표시에 쓴다.
    let isNew: Bool
    /// 같은 카드 번호라도 서로 다른 실물 판형을 구분한다.
    let finish: CardFinish

    init(id: String, tier: CardTier, isNew: Bool, finish: CardFinish = .normal) {
        self.id = id
        self.tier = tier
        self.isNew = isNew
        self.finish = finish
    }
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
        mode: OpeningMode = .game,
        using generator: inout some RandomNumberGenerator
    ) -> OpenedCards {
        draw(setID: setID, index: index, alreadyOwned: alreadyOwned, perks: perks,
             pity: &pity, mode: mode, forcedVariant: nil, using: &generator)
    }

    /// 실제 재화·보유량을 건드리지 않고 갓팩 구성과 연출을 확인할 때 쓴다.
    /// 세트 레시피에 등록된 갓팩만 강제할 수 있어 일반 팩에 가짜 갓팩을 만들지 않는다.
    static func godPackPreview(
        setID: String,
        index: CardIndex,
        alreadyOwned: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> OpenedCards? {
        let recipe = PackRecipe.forSet(setID, era: index.era(setID))
        guard let variant = recipe.specialRules.map(\.variant).first(where: \.isGodPack) else {
            return nil
        }
        var pity = 0
        let opened = draw(setID: setID, index: index, alreadyOwned: alreadyOwned,
                          perks: .none, pity: &pity, mode: .realistic,
                          forcedVariant: variant, using: &generator)
        guard opened.variant == variant,
              opened.cards.count == recipe.contents.gameCardCount else { return nil }
        return opened
    }

    private static func draw(
        setID: String,
        index: CardIndex,
        alreadyOwned: Set<String>,
        perks: DexPerks,
        pity: inout Int,
        mode: OpeningMode,
        forcedVariant: PackVariant?,
        using generator: inout some RandomNumberGenerator
    ) -> OpenedCards {
        let perks = mode == .realistic ? DexPerks.none : perks
        if mode == .realistic { pity = 0 }
        guard let pool = index.pools[setID], !pool.isEmpty else { return .empty }
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)
        let rolledVariant: PackVariant
        if let forcedVariant {
            rolledVariant = forcedVariant
        } else if let rule = recipe.specialVariant {
            let roll = Int(generator.next(upperBound: UInt64(rule.estimatedSimulatorOneIn)))
            rolledVariant = roll < recipe.specialRules.count
                ? recipe.specialRules[roll].variant : recipe.baseVariant
        } else {
            rolledVariant = recipe.baseVariant
        }

        var requests: [PackCardRequest] = []
        switch rolledVariant {
        case .scarletViolet151Demigod:
            // The evolution line atomically replaces reverse 1, reverse 2, and rare.
            requests = standardRequests(
                setID: setID,
                recipe: recipe,
                era: era,
                pool: pool,
                index: index,
                perks: perks,
                pity: &pity,
                excluding: [.reverseHolo, .reverseHoloHit, .rare],
                using: &generator
            )
            let lines = PackRecipe.scarletViolet151Lines
            let line = lines[Int(generator.next(upperBound: UInt64(lines.count)))]
            requests.append(contentsOf: line)
            pity = 0
        case .prismaticEvolutionsGod:
            requests = PackRecipe.prismaticEvolutionsGodPack
            pity = 0
        case .prismaticEvolutionsDemigod:
            requests = standardRequests(setID: setID, recipe: recipe, era: era, pool: pool,
                index: index, perks: perks, pity: &pity,
                excluding: [.reverseHolo, .reverseHoloHit, .rare], using: &generator)
            requests += Array(repeating: PackCardRequest(tier: .specialArtRare), count: 3)
            pity = 0
        case .blackBoltWhiteFlareGod:
            requests = PackRecipe.blackBoltWhiteFlareGodPack
            pity = 0
        case .ascendedHeroesGod:
            requests = PackRecipe.ascendedHeroesGodPack
            pity = 0
        case .standard, .celebrations:
            requests = standardRequests(
                setID: setID,
                recipe: recipe,
                era: era,
                pool: pool,
                index: index,
                perks: perks,
                pity: &pity,
                excluding: [],
                using: &generator
            )
        }

        // A broken catalogue must not turn a named God Pack into fallback rarities.
        if rolledVariant.isSpecialHit {
            for request in requests {
                if let id = request.exactCardID, index.card(id)?.setID != setID { return .empty }
                if request.exactCardID == nil && (pool[request.tier] ?? []).isEmpty { return .empty }
            }
        }
        var picked: [PackSlotResult] = []
        var usedInThisPack: Set<String> = []
        // 중복이 나와도 다시 뽑지 않는다. 값비싼 카드가 떴는데 「이미 가진 것」이라는 이유로
        // 더 싼 카드로 바뀌면, 도와주려던 장치가 오히려 뽑기를 망친 것으로 남는다.
        for request in requests {
            let exactID = request.exactCardID.flatMap { id in
                index.card(id)?.setID == setID ? id : nil
            }
            let id: String?
            if let exactID {
                id = exactID
            } else if let candidates = request.candidateCardIDs {
                id = pick(from: candidates, avoiding: usedInThisPack, using: &generator)
            } else {
                id = pick(tier: request.tier, from: pool,
                          avoiding: usedInThisPack, using: &generator)
            }
            guard let id else { continue }
            usedInThisPack.insert(id)
            let actualTier = index.card(id)?.tier ?? request.tier
            let baseCard = PulledCard(id: id, tier: actualTier,
                                      isNew: !alreadyOwned.contains(id))
            let unresolved = PackSlotResult(card: baseCard, finishHint: request.finishHint)
            let finish = unresolved.printing(setID: setID, index: index).finish
            let card = PulledCard(id: id, tier: actualTier,
                                  isNew: !alreadyOwned.contains(id), finish: finish)
            picked.append(PackSlotResult(card: card, finishHint: request.finishHint))
        }
        // 일부 영문 스페셜 세트는 번호 없는 기본 에너지도 reverse 슬롯 후보였다. 일반
        // 에너지 자리는 그대로 남으므로 당첨 팩에는 에너지 두 장이 보이는 것이 정상이다.
        if let energyFinish = PackRecipe.reverseSlotEnergyFinish[setID],
           Int.random(in: 0..<PackRecipe.estimatedReverseSlotEnergyOneIn(setID: setID),
                      using: &generator) == 0,
           let reverseIndex = picked.firstIndex(where: { $0.card.finish == .reverseHolo }) {
            let energy = SupplementalEnergyCard.randomCard(
                setID: setID, era: era, finish: energyFinish, using: &generator
            )
            picked[reverseIndex] = PackSlotResult(card: energy, finishHint: .defaultForCard)
        }
        if mode == .realistic { pity = 0 }
        return OpenedCards(slotResults: picked, variant: rolledVariant)
    }

    private static func standardRequests(
        setID: String,
        recipe: PackRecipe,
        era: PackEra,
        pool: [CardTier: [String]],
        index: CardIndex,
        perks: DexPerks,
        pity: inout Int,
        excluding excludedKinds: Set<PackSlotKind>,
        using generator: inout some RandomNumberGenerator
    ) -> [PackCardRequest] {
        let tables = PackConfig.slotTables(setID: setID, era: era)
        var requests: [PackCardRequest] = []
        var hitTiers: [CardTier] = []

        for (slot, table) in zip(recipe.slots, tables) {
            guard !excludedKinds.contains(slot.kind) else { continue }
            let availablePool = slotPool(
                setID: setID, slot: slot.kind, pool: pool, index: index)
            // Radiant Collection sheets are guaranteed physical positions; the
            // game-wide hit perk must not turn their fixed sheet ratio into a
            // different product.
            let weights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: perks)
            for _ in 0..<slot.count {
                if let parallel = prismaticParallelRequest(
                    setID: setID,
                    slot: slot.kind,
                    pool: pool,
                    using: &generator
                ) {
                    requests.append(parallel)
                    continue
                }
                let tier: CardTier
                if slot.kind == .rare && recipe.baseVariant != .celebrations {
                    tier = hitTier(available: availablePool, era: era,
                                   baseWeights: table.weights, perks: perks,
                                   pity: pity, using: &generator)
                    hitTiers.append(tier)
                } else {
                    tier = weightedTier(weights, available: availablePool, using: &generator)
                }
                let candidates = usesRestrictedCandidatePool(
                    setID: setID, slot: slot.kind)
                    ? availablePool[tier]
                    : nil
                requests.append(PackCardRequest(
                    tier: tier,
                    candidateCardIDs: candidates,
                    finishHint: finishHint(setID: setID, slot: slot.kind,
                                           tier: tier, era: era)
                ))
            }
        }

        if !hitTiers.isEmpty {
            pity = nextPity(after: hitTiers, from: pity)
        }
        return requests
    }

    /// Separates the two RC sheets from the eight core-set positions. Without
    /// this filter, sharing a parent set ID lets an RC-numbered Common leak into
    /// any generic Common position even when the two guaranteed RC positions
    /// are already filled.
    static func slotPool(
        setID: String,
        slot: PackSlotKind,
        pool: [CardTier: [String]],
        index: CardIndex? = nil
    ) -> [CardTier: [String]] {
        PackOdds.restrict(physicalSlotPool(setID: setID, slot: slot, pool: pool, index: index),
                          setID: setID, slot: slot, index: index)
    }

    private static func physicalSlotPool(
        setID: String,
        slot: PackSlotKind,
        pool: [CardTier: [String]],
        index: CardIndex?
    ) -> [CardTier: [String]] {
        if setID == "cel30", let index {
            return pool.mapValues { ids in
                ids.filter { id in
                    let isPikachuRare = index.card(id)?.rarity == "Pikachu Rare"
                    return slot == .anniversaryPikachu ? isPikachuRare : !isPikachuRare
                }
            }
        }
        if usesEXReverseRareHoloPool(setID: setID, slot: slot), let index {
            var reversePool = pool
            reversePool[.doubleRare] = (pool[.doubleRare] ?? []).filter {
                index.card($0)?.rarity == "Rare Holo"
            }
            return reversePool
        }

        if PackRecipe.isRadiantCollectionSet(setID),
           slot == .radiantCollectionCommon || slot == .radiantCollectionHigh {
            var restricted: [CardTier: [String]] = [:]
            for tier in CardTier.allCases {
                let allowed = Set(PackRecipe.radiantCollectionIDs(
                    setID: setID, slot: slot, tier: tier
                ))
                guard !allowed.isEmpty else { continue }
                restricted[tier] = (pool[tier] ?? []).filter(allowed.contains)
            }
            return restricted
        }

        if PackRecipe.isRadiantCollectionSet(setID) {
            let corePool = pool.mapValues { ids in
                ids.filter { !$0.hasPrefix("\(setID)-RC") }
            }
            guard setID == "bw11" else { return corePool }

            let holoIDs = Set(PackRecipe.legendaryTreasuresHoloIDs)
            if slot == .legendaryTreasuresReverse {
                var reversePool = corePool
                reversePool[.doubleRare] = (corePool[.doubleRare] ?? []).filter(holoIDs.contains)
                return reversePool
            }
            if slot == .rare {
                var rarePool = corePool
                rarePool[.doubleRare] = (corePool[.doubleRare] ?? []).filter {
                    !holoIDs.contains($0)
                }
                return rarePool
            }
            return corePool
        }

        guard let subsetPrefix = separatelyNumberedSubsetPrefix(parentSetID: setID) else {
            return pool
        }
        let prefix = subsetPrefix + "-"

        if slot == .classicCollection {
            return pool.mapValues { ids in
                let subsetCards = ids.filter { $0.hasPrefix(prefix) }
                if !subsetCards.isEmpty { return subsetCards }
                return ids.filter { !$0.hasPrefix(prefix) }
            }
        }

        if slot == .reverseHolo {
            return pool.mapValues { ids in
                let subsetCards = ids.filter { $0.hasPrefix(prefix) }
                // Imported subset tiers (S/SSR/CHR/AR/SAR) are distinct from
                // the parent C/U/R tiers. If a tier exists on the replacement
                // sheet, that physical slot must draw from that sheet only.
                if !subsetCards.isEmpty { return subsetCards }
                return ids.filter { !$0.hasPrefix(prefix) }
            }
        }

        return pool.mapValues { ids in
            ids.filter { !$0.hasPrefix(prefix) }
        }
    }

    private static func separatelyNumberedSubsetPrefix(parentSetID: String) -> String? {
        [
            "sm115": "sma",
            "swsh45": "swsh45sv",
            "cel25": "cel25c",
            "swsh9": "swsh9tg",
            "swsh10": "swsh10tg",
            "swsh11": "swsh11tg",
            "swsh12": "swsh12tg",
            "swsh12pt5": "swsh12pt5gg",
        ][parentSetID]
    }

    static func usesConstrainedSlotPool(setID: String) -> Bool {
        setID == "cel30" || PackRecipe.isRadiantCollectionSet(setID)
            || separatelyNumberedSubsetPrefix(parentSetID: setID) != nil
    }

    /// Whether a physical slot draws from a card-ID subset rather than every
    /// card in its rarity tier. Pricing uses the same predicate as opening so
    /// the expected value cannot drift from the cards that are actually drawn.
    static func usesRestrictedCandidatePool(
        setID: String,
        slot: PackSlotKind
    ) -> Bool {
        usesConstrainedSlotPool(setID: setID)
            || usesEXReverseRareHoloPool(setID: setID, slot: slot)
            || PackOdds.poolRules(setID: setID, slot: slot) != nil
    }

    private static func usesEXReverseRareHoloPool(
        setID: String,
        slot: PackSlotKind
    ) -> Bool {
        guard slot == .reverseHolo, setID.hasPrefix("ex"),
              let number = Int(setID.dropFirst(2)) else { return false }
        return (5...16).contains(number)
    }

    /// Prismatic Evolutions·Black Bolt·White Flare의 역홀로 두 칸은 일반
    /// 역홀로뿐 아니라 별도 체크리스트의 Poké Ball·Master Ball 미러를 낸다.
    /// rarity는 그대로 C/U/R이므로 카드 번호와 finish를 함께 고정한다.
    private static func prismaticParallelRequest(
        setID: String,
        slot: PackSlotKind,
        pool: [CardTier: [String]],
        using generator: inout some RandomNumberGenerator
    ) -> PackCardRequest? {
        guard let hits = PackRecipe.observedParallelHits(setID: setID, slot: slot),
              generator.next(upperBound: UInt64(PackRecipe.prismaticParallelRolls))
                < UInt64(hits) else { return nil }

        let finishHint: PackFinishHint
        let eligible: [(tier: CardTier, id: String)]
        switch slot {
        case .reverseHolo:
            finishHint = .pokeBallParallel
            eligible = prismaticParallelCandidates(
                setID: setID, pool: pool, masterBallOnly: false
            )
        case .reverseHoloHit:
            finishHint = .masterBallParallel
            eligible = prismaticParallelCandidates(
                setID: setID, pool: pool, masterBallOnly: true
            )
        default:
            return nil
        }
        guard !eligible.isEmpty else { return nil }
        let picked = eligible[Int(generator.next(upperBound: UInt64(eligible.count)))]
        return PackCardRequest(tier: picked.tier, exactCardID: picked.id,
                               finishHint: finishHint)
    }

    /// Prismatic Evolutions의 Poké Ball은 C/U/R 전체, Master Ball은 001~090이다.
    /// Black Bolt·White Flare는 Poké Ball 001~086, Master Ball 001~078이며,
    /// 둘 다 C/U/R 인쇄본만 존재한다. compact index에서는 카드 ID의 마지막
    /// 번호가 실물 체크리스트 번호와 같다.
    static func prismaticParallelCandidates(
        setID: String,
        pool: [CardTier: [String]],
        masterBallOnly: Bool
    ) -> [(tier: CardTier, id: String)] {
        let eligibleNumbers: ClosedRange<Int>?
        switch setID {
        case "sv8pt5":
            eligibleNumbers = masterBallOnly ? 1...90 : nil
        case "rsv10pt5", "zsv10pt5":
            eligibleNumbers = masterBallOnly ? 1...78 : 1...86
        default:
            return []
        }

        return [CardTier.common, .uncommon, .rare].flatMap { tier in
            (pool[tier] ?? []).compactMap { id in
                if let eligibleNumbers {
                    guard let number = Int(id.split(separator: "-").last ?? ""),
                          eligibleNumbers.contains(number) else { return nil }
                }
                return (tier: tier, id: id)
            }
        }
    }

    static func finishHint(setID: String, slot: PackSlotKind, tier: CardTier,
                           era: PackEra) -> PackFinishHint {
        if let measured = PackOdds.finishHint(setID: setID, slot: slot, tier: tier) {
            return measured
        }
        switch slot {
        case .energy, .common, .uncommon:
            return .normal
        case .reverseHolo, .reverseHoloHit:
            if setID == "me2pt5" && slot == .reverseHoloHit && tier.rank <= CardTier.rare.rank {
                return .ascendedParallel
            }
            if setID == "dc1" { return .reverseHolo }
            if usesEXReverseRareHoloPool(setID: setID, slot: slot),
               tier == .doubleRare {
                return .reverseHolo
            }
            return tier.rank <= CardTier.rare.rank ? .reverseHolo : .defaultForCard
        case .legendaryTreasuresReverse:
            return tier == .doubleRare ? .defaultForCard : .reverseHolo
        case .rare:
            if era == .scarletViolet && tier == .rare { return .holoRare }
            return .defaultForCard
        case .allFoil, .anniversaryPikachu, .celebrationsHolo, .classicCollection, .celebrationsRare:
            return .allFoil
        case .radiantCollectionCommon:
            // Generations RC Commons are non-foil; every Legendary Treasures
            // RC card has the subset coating/foil treatment.
            return setID == "bw11" ? .allFoil : .normal
        case .radiantCollectionHigh:
            return .allFoil
        }
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
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)

        var expected: [CardTier: Double] = [:]

        func addWeighted(_ weights: [(tier: CardTier, weight: Int)], slots: Double,
                         availablePool: [CardTier: [String]]) {
            let available = weights.filter { !(availablePool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0, slots > 0 else { return }
            for entry in available {
                let p = Double(entry.weight) / Double(total)
                expected[entry.tier, default: 0] += p * slots
            }
        }

        let specialChance = recipe.specialVariant.map {
            1.0 / Double($0.estimatedSimulatorOneIn)
        } ?? 0
        let tables = PackConfig.slotTables(setID: setID, era: era)
        for (slot, table) in zip(recipe.slots, tables) {
            let standardShare = recipe.standardShare(for: slot.kind)
            let availablePool = slotPool(setID: setID, slot: slot.kind, pool: pool, index: index)
            let effectiveWeights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: perks)

            if let hits = PackRecipe.observedParallelHits(setID: setID, slot: slot.kind) {
                let parallelChance = Double(hits) / Double(PackRecipe.prismaticParallelRolls)
                addWeighted(effectiveWeights,
                            slots: Double(slot.count) * standardShare * (1 - parallelChance), availablePool: availablePool)

                let candidates = prismaticParallelCandidates(
                    setID: setID,
                    pool: pool,
                    masterBallOnly: slot.kind == .reverseHoloHit
                )
                let candidateCount = Double(candidates.count)
                guard candidateCount > 0 else {
                    addWeighted(effectiveWeights,
                                slots: Double(slot.count) * standardShare * parallelChance, availablePool: availablePool)
                    continue
                }
                for tier in [CardTier.common, .uncommon, .rare] {
                    let count = Double(candidates.lazy.filter { $0.tier == tier }.count)
                    expected[tier, default: 0] += Double(slot.count) * standardShare
                        * parallelChance * count / candidateCount
                }
                continue
            }
            addWeighted(effectiveWeights,
                        slots: Double(slot.count) * standardShare, availablePool: availablePool)
        }

        func addRequest(_ request: PackCardRequest, share: Double) {
            if let id = request.exactCardID,
               let card = index.card(id), card.setID == setID {
                expected[card.tier, default: 0] += share
                return
            }
            if let fallback = request.tier.fallbackChain.first(where: {
                !(pool[$0] ?? []).isEmpty
            }) {
                expected[fallback, default: 0] += share
            }
        }

        switch recipe.specialVariant?.variant {
        case .scarletViolet151Demigod:
            // Every line has the same 2 IR + 1 SIR tier shape.
            for request in PackRecipe.scarletViolet151Lines[0] {
                addRequest(request, share: specialChance)
            }
        case .prismaticEvolutionsGod:
            for request in PackRecipe.prismaticEvolutionsGodPack {
                addRequest(request, share: specialChance)
            }
            addRequest(PackCardRequest(tier: .specialArtRare), share: specialChance * 3)
        case .blackBoltWhiteFlareGod:
            for request in PackRecipe.blackBoltWhiteFlareGodPack {
                addRequest(request, share: specialChance)
            }
        case .ascendedHeroesGod:
            for request in PackRecipe.ascendedHeroesGodPack {
                addRequest(request, share: specialChance)
            }
        case .standard, .celebrations, .prismaticEvolutionsDemigod, nil:
            break
        }

        let cardsPerPack = expected.values.reduce(0, +)
        guard cardsPerPack > 0 else { return [] }
        return expected.keys
            .map { TierOdds(tier: $0, probability: (expected[$0] ?? 0) / cardsPerPack) }
            .sorted { $0.tier.rank > $1.tier.rank }
    }

    /// 카드 한 장이 팩 하나에 들어 있는 기대 장수.
    ///
    /// `packOdds` 는 등급 단위 공시라 같은 등급의 카드를 똑같이 나눠 갖는다고 본다. 세트별
    /// 실측표는 같은 등급 안에서도 칸을 가른다 — HGSS 의 Prime 은 역홀로 칸에서 여섯 팩에 한
    /// 장, 30주년의 RGB 뮤는 3,300팩에 한 장이다. 도감 난이도와 「한 팩에서 나올 확률」은
    /// 카드 단위라, 칸마다 실제로 뽑히는 풀로 나눠 센다.
    static func cardPullRates(setID: String, index: CardIndex,
                              perks: DexPerks = .none) -> [String: Double] {
        let pool = index.pools[setID] ?? [:]
        guard !pool.isEmpty else { return [:] }
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)
        var rates: [String: Double] = [:]

        func spread(_ weights: [(tier: CardTier, weight: Int)], slots: Double,
                    availablePool: [CardTier: [String]]) {
            let available = weights.filter { !(availablePool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0, slots > 0 else { return }
            for entry in available {
                let ids = availablePool[entry.tier] ?? []
                let each = Double(entry.weight) / Double(total) * slots / Double(ids.count)
                for id in ids { rates[id, default: 0] += each }
            }
        }

        let tables = PackConfig.slotTables(setID: setID, era: era)
        for (slot, table) in zip(recipe.slots, tables) {
            let slots = Double(slot.count) * recipe.standardShare(for: slot.kind)
            let availablePool = slotPool(setID: setID, slot: slot.kind, pool: pool, index: index)
            let weights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: perks)
            if let hits = PackRecipe.observedParallelHits(setID: setID, slot: slot.kind) {
                let candidates = prismaticParallelCandidates(
                    setID: setID, pool: pool, masterBallOnly: slot.kind == .reverseHoloHit)
                if !candidates.isEmpty {
                    let chance = Double(hits) / Double(PackRecipe.prismaticParallelRolls)
                    spread(weights, slots: slots * (1 - chance), availablePool: availablePool)
                    for candidate in candidates {
                        rates[candidate.id, default: 0] += slots * chance / Double(candidates.count)
                    }
                    continue
                }
            }
            spread(weights, slots: slots, availablePool: availablePool)
        }

        let specialChance = recipe.specialVariant.map {
            1.0 / Double($0.estimatedSimulatorOneIn)
        } ?? 0
        func add(_ request: PackCardRequest, share: Double) {
            if let id = request.exactCardID, index.card(id)?.setID == setID {
                rates[id, default: 0] += share
                return
            }
            guard let tier = request.tier.fallbackChain.first(where: { !(pool[$0] ?? []).isEmpty }),
                  let ids = pool[tier] else { return }
            for id in ids { rates[id, default: 0] += share / Double(ids.count) }
        }
        switch recipe.specialVariant?.variant {
        case .scarletViolet151Demigod:
            for request in PackRecipe.scarletViolet151Lines.flatMap({ $0 }) {
                add(request, share: specialChance / Double(PackRecipe.scarletViolet151Lines.count))
            }
        case .prismaticEvolutionsGod:
            for request in PackRecipe.prismaticEvolutionsGodPack {
                add(request, share: specialChance)
            }
            add(PackCardRequest(tier: .specialArtRare), share: specialChance * 3)
        case .blackBoltWhiteFlareGod:
            for request in PackRecipe.blackBoltWhiteFlareGodPack {
                add(request, share: specialChance)
            }
        case .ascendedHeroesGod:
            for request in PackRecipe.ascendedHeroesGodPack {
                add(request, share: specialChance)
            }
        case .standard, .celebrations, .prismaticEvolutionsDemigod, nil:
            break
        }
        return rates
    }

    /// 그 시대 팩의 칸 표. 뽑기·기대 구성·공시가 모두 이 하나를 본다 —
    /// 세 곳에 따로 적으면 표시된 확률과 실제 결과가 갈라진다.
    static func standardSlotTables(era: PackEra, perks: DexPerks)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        PackConfig.slotTables(era).map {
            (weights: PackConfig.weights($0.weights, perks: perks), count: $0.count)
        }
    }

    static func slotTables(setID: String, era: PackEra, perks: DexPerks)
        -> [(weights: [(tier: CardTier, weight: Int)], count: Int)] {
        let recipe = PackRecipe.forSet(setID, era: era)
        return zip(recipe.slots, PackConfig.slotTables(setID: setID, era: era)).map {
            let weights = $0.0.kind == .radiantCollectionHigh
                ? $0.1.weights
                : PackConfig.weights($0.1.weights, perks: perks)
            return (weights: weights, count: $0.1.count)
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

        return Self.slotTables(setID: setID, era: index.era(setID), perks: perks)
            .enumerated().map { offset, table in
            PackSlot(id: offset, count: table.count, guaranteed: nil, odds: odds(table.weights))
        }
    }

    /// 히트 슬롯만의 등급 분포. 뽑기 내부와 상세 표시가 같은 값을 쓰도록 남겨 둔다.
    static func hitOdds(setID: String, index: CardIndex) -> [(tier: CardTier, probability: Double)] {
        let pool = index.pools[setID] ?? [:]
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)
        let rareSlot = zip(recipe.slots, PackConfig.slotTables(setID: setID, era: era))
            .first { $0.0.kind == .rare }?.1.weights
        let weights = recipe.baseVariant == .celebrations
            ? PackConfig.specialWeights
            : rareSlot ?? PackConfig.rareWeights(era)
        let available = weights.filter { !(pool[$0.tier] ?? []).isEmpty }
        let total = available.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [] }
        return available
            .map { (tier: $0.tier, probability: Double($0.weight) / Double(total)) }
            .sorted { $0.tier.rank > $1.tier.rank }
    }

    /// 개봉에서 보여줄 순서. `draw`가 세트 레시피의 슬롯 순서대로 카드를 만들므로
    /// 여기서는 그 순서를 그대로 보존한다. 희귀도 재정렬을 하면 리버스 슬롯의 IR/SIR,
    /// Radiant Collection, 기념팩의 고정 카드, 갓팩 배열이 실물과 달라진다.
    static func revealOrder(_ cards: [PulledCard]) -> [PulledCard] {
        cards
    }

    /// 히트 슬롯의 계층을 가중 추첨한다. 그 세트에 없는 계층은 후보에서 빼고 가중치를 다시 정규화한다.
    /// 빼지 않으면 1999년 세트에서 시크릿을 뽑았다고 판정하고 폴백으로 흘러가 확률이 왜곡된다.
    static func hitTier(
        available pool: [CardTier: [String]],
        era: PackEra = .scarletViolet,
        baseWeights: [(tier: CardTier, weight: Int)]? = nil,
        perks: DexPerks = .none,
        pity: Int = 0,
        using generator: inout some RandomNumberGenerator
    ) -> CardTier {
        var weights = PackConfig.weights(baseWeights ?? PackConfig.rareWeights(era), perks: perks)
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

    /// Picks from one physical sheet while preserving the pack-wide duplicate
    /// avoidance used by ordinary tier pools.
    private static func pick(
        from ids: [String],
        avoiding used: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> String? {
        guard !ids.isEmpty else { return nil }
        let fresh = ids.filter { !used.contains($0) }
        let source = fresh.isEmpty ? ids : fresh
        return source[Int(generator.next(upperBound: UInt64(source.count)))]
    }
}
