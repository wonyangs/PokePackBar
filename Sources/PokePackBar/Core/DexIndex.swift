import Foundation

/// 도감이 완성될 때 붙는 영구 혜택의 종류.
///
/// 값은 전부 "더해지는 양" 이다. 곱셈으로 두면 도감이 늘어날 때마다 폭주한다.
enum DexPerkKind: String, Codable, Sendable, CaseIterable {
    case tokenGain          // 적립 토큰 +x
    case packDiscount       // 팩 가격 -x
    case dustBonus          // 판매 추가금 +x
    case hitOdds            // 히트 슬롯에서 레어 비중을 x 만큼 상위 등급으로 넘긴다
}

struct DexPerk: Codable, Sendable, Equatable {
    let kind: DexPerkKind
    let value: Double
}

/// 팩 할인 쿠폰 한 묶음. **그 도감의 세트 팩에만 쓴다.**
///
/// 처음에는 「다음 팩 몇 개 동안 반값」이라는 한시 혜택으로 뒀는데 두 가지가 잘못됐다.
///
/// 첫째, 어느 세트에나 걸리니 **가장 비싼 팩을 노리고 돈을 모으는 것이 최적**이 된다 —
/// 보상이 소비를 막는다. 둘째, 팩값에 조용히 곱해질 뿐이라 사용자가 체감할 수 없다.
///
/// 쿠폰은 세트가 정해져 있어 아껴 둘 이유가 없고, 상점이 「쿠폰 2장 · 정가에 줄을 긋고
/// 할인가」로 적을 수 있어 눈에 보인다.
struct DexCouponGrant: Codable, Sendable, Equatable {
    let value: Double
    let count: Int
}

/// 갖고 있는 쿠폰. **세트가 정해져 있다** — 수령한 도감의 `homeSet` 이다.
struct PackCoupon: Codable, Sendable, Equatable {
    let setID: String
    let value: Double
    var left: Int
}

/// 확정 카드 한 장.
///
/// **등급 하한이 아니라 값으로 뽑는다.** 「UR 이상 랜덤 1장」의 실제 중앙값이 17,400원인데
/// 평균은 160,600원이다 — 분포가 아래로 쏠려 있어 등급만 정하면 대개 1~2만원짜리가 나온다.
/// 오리파에서 겪은 것과 같은 문제고, 답도 같다.
struct DexCardGrant: Codable, Sendable, Equatable {
    /// 뽑을 값(달러). 이 값에 가장 가까운 카드를 준다.
    let targetUSD: Double
    /// 화면에 적을 등급 하한. **표시용이다** — 실제 선택은 값이 한다.
    let tierFloor: String
}

struct DexReward: Codable, Sendable, Equatable {
    /// 수령 시 주는 팩. 도감의 `homeSet` 팩이다.
    let packs: Int
    /// 영구 혜택. **테마 도감과 완성 수 계단에만 있다** — 세트 도감 122개까지 나누면
    /// 한 칸이 0.1% 도 안 되어 보상이 아니게 된다.
    let perks: [DexPerk]
    /// 그대로 주는 토큰.
    var tokens: Int = 0
    var coupons: [DexCouponGrant] = []
    var card: DexCardGrant? = nil

    static let none = DexReward(packs: 0, perks: [])

    init(packs: Int, perks: [DexPerk], tokens: Int = 0, coupons: [DexCouponGrant] = [],
         card: DexCardGrant? = nil) {
        self.packs = packs
        self.perks = perks
        self.tokens = tokens
        self.coupons = coupons
        self.card = card
    }

    /// 손으로 읽는다. **빠진 열쇠는 기본값으로 둔다** — 통로를 하나 더 붙일 때마다 예전
    /// `dex.json` 과 테스트 픽스처가 통째로 못 읽히면 안 된다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        packs = (try? c.decode(Int.self, forKey: .packs)) ?? 0
        perks = (try? c.decode([DexPerk].self, forKey: .perks)) ?? []
        tokens = (try? c.decode(Int.self, forKey: .tokens)) ?? 0
        coupons = (try? c.decode([DexCouponGrant].self, forKey: .coupons)) ?? []
        card = try? c.decodeIfPresent(DexCardGrant.self, forKey: .card)
    }

    /// 무언가라도 주는가. 아무것도 안 주는 칸은 수령 버튼을 띄우지 않는다.
    var isEmpty: Bool {
        packs == 0 && perks.isEmpty && tokens == 0 && coupons.isEmpty && card == nil
    }

    /// 화면에 칩이 몇 개 붙는가. 보상 줄의 높이가 이 수에서 나온다.
    var channelCount: Int {
        perks.count + coupons.count + (packs > 0 ? 1 : 0) + (tokens > 0 ? 1 : 0)
            + (card == nil ? 0 : 1)
    }
}

/// 세트 도감의 마일스톤 한 칸 — 그 세트의 종을 몇 할까지 모으는가.
struct DexMilestone: Codable, Sendable, Equatable {
    let fraction: Double
    /// 필요한 종 수.
    let need: Int
    let medianPacks: Int
    let medianTokens: Int
    let reward: DexReward
}

/// 완성 수 계단 한 칸.
///
/// **영구 혜택을 도감에서 여기로 옮긴 것이 이번 개편의 핵심이다.** 도감 하나하나에 붙이면
/// 도감이 늘 때마다 예산을 나눠 가져 한 칸이 0.1% 가 된다. 계단으로 옮기면 도감을 몇 개
/// 더 붙여도 예산이 늘지 않는다.
struct DexLadderStep: Codable, Sendable, Equatable, Identifiable {
    /// 이 칸이 열리는 완성 도감 수.
    let completed: Int
    let title: DexText
    let perks: [DexPerk]

    var id: Int { completed }
}

/// 한국어 정본 + 영어. 카드 팩 소개(`packBlurb`)와 같은 방식이다 —
/// 도감 이름은 문안이 길고 수가 계속 늘어나서 6개 언어를 전부 유지할 수 없다.
struct DexText: Codable, Sendable, Equatable {
    let ko: String
    let en: String

    func text(_ language: AppLanguage) -> String { language == .ko ? ko : en }
}

/// 도감의 두 갈래.
///
/// 손으로 짓는 테마 도감이 7세트만 덮고 있었다. 122세트를 사람이 훑을 수는 없으므로
/// **세트 도감은 세트 하나만 가리키고 구성 카드를 나열하지 않는다** — 그 세트의 종 전부가
/// 대상이고, 284장을 `dex.json` 에 적으면 파일이 열 배가 된다.
enum DexKind: String, Codable, Sendable {
    /// 정해진 카드를 다 모으는 조합. `cards` 가 곧 목표다.
    case theme
    /// 그 세트의 종을 몇 할까지 모으는 것. `milestones` 가 목표다.
    case set
}

/// 카드 몇 장을 묶은 조합.
struct Dex: Sendable, Identifiable, Equatable {
    let id: String
    var kind: DexKind = .theme
    let name: DexText
    let blurb: DexText
    /// 「이 팩 사러 가기」와 보상 팩의 세트. 구성원이 여러 세트에 걸쳐도 하나로 정한다.
    let homeSet: String
    let cards: [String]
    /// 난이도 1~5. `scripts/build_dex.py` 가 실제 확률로 계산해 넣는다.
    let tier: Int
    /// 완성까지 필요한 팩 수(50% 지점). 화면에 함께 보여 준다.
    let medianPacks: Int
    /// 완성까지 드는 토큰(50% 지점). 참고용으로 남긴다.
    let medianTokens: Int
    /// 도감에 든 카드값의 합(달러). **난이도와 정렬이 이 값을 쓴다.**
    let valueUSD: Double
    let reward: DexReward
    /// 세트 도감의 마일스톤. 테마 도감은 비어 있다.
    var milestones: [DexMilestone] = []

    /// 난이도 상한. 표시(별)와 보상표가 이 범위를 벗어나지 않는다.
    static let maxTier = 5

    /// 수령 기록에 쓰는 열쇠.
    ///
    /// **테마 도감은 예전처럼 id 하나를 쓴다.** 이미 수령한 세이브의 기록이 `id` 로 남아
    /// 있고, 열쇠를 바꾸면 그 사람들의 혜택이 조용히 사라진다. 칸이 여럿인 세트 도감만
    /// 번호를 붙인다.
    func claimKey(_ step: Int) -> String { kind == .set ? "\(id)#\(step)" : id }

    /// 이 도감이 완성으로 세어지는 열쇠 — 계단이 이것을 센다.
    ///
    /// 세트 도감은 **마지막 칸**이다. 중간 칸까지 세면 세트 도감 하나가 계단을 세 칸
    /// 밀어 올린다.
    var completionKey: String { claimKey(kind == .set ? milestones.count - 1 : 0) }
}

/// 완성한 도감들이 주는 혜택의 합.
///
/// 상한을 둔다. 도감은 계속 늘어날 것이고, 상한이 없으면 언젠가 팩이 공짜가 된다.
/// 상한값은 `scripts/build_dex.py` 의 `PERK_CAPS` 와 같아야 한다 — 그쪽은 도감을
/// 추가하다 총합이 상한을 넘으면 빌드를 실패시킨다.
struct DexPerks: Sendable, Equatable {
    var tokenGain: Double = 0
    var packDiscount: Double = 0
    var dustBonus: Double = 0
    var hitOdds: Double = 0

    static let none = DexPerks()

    /// 상한값은 되팔기 회수율이 정한다.
    ///
    /// 팩을 사서 전부 팔았을 때의 기대 수입이 팩 값에 가까워지면 팩을 돌리는 것 자체가
    /// 재화 순환이 되어 게임이 성립하지 않는다.
    ///
    /// 「히트 칸 +1」을 없애면서 전부 올렸다. 그 혜택 하나가 이 비율을 32% 에서 53% 로 밀어
    /// 올려 다른 혜택을 얹을 자리를 먹고 있었다. 빼고 나니 상한을 올려도 최악이 52% 다.
    /// 세트가 126개가 되면서 팩값이 4,000배로 벌어져, 가장 비싼 도감의 보상을 채우려면
    /// 예전 상한으로는 모자라기도 했다. `DexPerkEffectTests` 가 이 선을 지킨다.
    ///
    /// 판매 추가금만 다른 것보다 상한이 높다. **한 점의 값이 6분의 1이기 때문이다** —
    /// 팩값 전체에 걸리는 할인·획득량과 달리 이것은 판 카드에만, 그것도 절반만 걸린다.
    /// 같은 크기의 보상을 주려면 숫자가 그만큼 커야 한다.
    static let caps = DexPerks(tokenGain: 0.25, packDiscount: 0.15, dustBonus: 0.15,
                               hitOdds: 0.20)

    /// 완성한 도감에서 혜택을 모은다. 상한을 넘으면 상한에서 멈춘다.
    ///
    /// 완성 목록에 없는 id 는 무시한다 — 도감을 지우거나 이름을 바꿔도 세이브가 깨지지 않는다.
    static func total(completed: Set<String>, dexes: [Dex],
                      ladder: [DexLadderStep] = []) -> DexPerks {
        var perks = DexPerks()
        for dex in dexes where completed.contains(dex.id) {
            perks.add(dex.reward.perks)
        }
        // 계단은 **완성 수**를 세어 열린다. 도감 하나하나의 혜택과 달리 도감이 늘어도
        // 예산이 늘지 않는다 — 그래서 자동 생성 도감을 마음껏 붙일 수 있다.
        let done = dexes.filter { completed.contains($0.completionKey) }.count
        for step in ladder where done >= step.completed {
            perks.add(step.perks)
        }
        return perks.clamped()
    }

    private mutating func add(_ list: [DexPerk]) {
        for perk in list {
            switch perk.kind {
            case .tokenGain:    tokenGain += perk.value
            case .packDiscount: packDiscount += perk.value
            case .dustBonus:    dustBonus += perk.value
            case .hitOdds:      hitOdds += perk.value
            }
        }
    }

    private func clamped() -> DexPerks {
        DexPerks(tokenGain: min(tokenGain, Self.caps.tokenGain),
                 packDiscount: min(packDiscount, Self.caps.packDiscount),
                 dustBonus: min(dustBonus, Self.caps.dustBonus),
                 hitOdds: min(hitOdds, Self.caps.hitOdds))
    }

    var isEmpty: Bool { self == .none }
}

/// 앱에 번들된 도감 목록.
struct DexIndex: Sendable {
    let dexes: [Dex]
    /// 완성 수 계단. 영구 혜택의 주인이다.
    var ladder: [DexLadderStep] = []

    private let byID: [String: Dex]

    func dex(_ id: String) -> Dex? { byID[id] }

    /// 이 카드가 들어가는 도감들. 카드 상세에서 "어디에 쓰이는 카드인가" 를 보여줄 때 쓴다.
    func dexes(containing cardID: String) -> [Dex] {
        dexes.filter { $0.cards.contains(cardID) }
    }

    /// 완성으로 세어지는 칸의 총수. 계단의 마지막 칸이 이 값에 맞춰져 있다.
    var completableCount: Int { dexes.count }

    /// 세트 도감만. 화면이 갈래로 나눌 때 쓴다.
    var setDexes: [Dex] { dexes.filter { $0.kind == .set } }
    var themeDexes: [Dex] { dexes.filter { $0.kind == .theme } }

    init(dexes: [Dex], ladder: [DexLadderStep] = []) {
        self.dexes = dexes
        self.ladder = ladder
        byID = Dictionary(dexes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: 로딩

    private struct Payload: Decodable {
        struct DexDTO: Decodable {
            let id: String
            var kind: DexKind = .theme
            let name: DexText
            let blurb: DexText
            let homeSet: String
            var cards: [String] = []
            let tier: Int
            var medianPacks: Int = 0
            var medianTokens: Int = 0
            var valueUSD: Double = 0
            var reward: DexReward = .none
            var milestones: [DexMilestone] = []

            enum CodingKeys: String, CodingKey {
                case id, kind, name, blurb, homeSet, cards, tier
                case medianPacks, medianTokens, valueUSD, reward, milestones
            }

            /// 손으로 읽는다. 빠진 열쇠는 기본값으로 둔다 — 옛 `dex.json` 도 읽혀야 한다.
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id = try c.decode(String.self, forKey: .id)
                kind = (try? c.decode(DexKind.self, forKey: .kind)) ?? .theme
                name = try c.decode(DexText.self, forKey: .name)
                blurb = (try? c.decode(DexText.self, forKey: .blurb))
                    ?? DexText(ko: "", en: "")
                homeSet = try c.decode(String.self, forKey: .homeSet)
                cards = (try? c.decode([String].self, forKey: .cards)) ?? []
                tier = try c.decode(Int.self, forKey: .tier)
                medianPacks = (try? c.decode(Int.self, forKey: .medianPacks)) ?? 0
                medianTokens = (try? c.decode(Int.self, forKey: .medianTokens)) ?? 0
                valueUSD = (try? c.decode(Double.self, forKey: .valueUSD)) ?? 0
                reward = (try? c.decode(DexReward.self, forKey: .reward)) ?? .none
                milestones = (try? c.decode([DexMilestone].self, forKey: .milestones)) ?? []
            }
        }
        let version: Int
        let dexes: [DexDTO]
        var ladder: [DexLadderStep] = []

        enum CodingKeys: String, CodingKey { case version, dexes, ladder }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = (try? c.decode(Int.self, forKey: .version)) ?? 1
            dexes = try c.decode([DexDTO].self, forKey: .dexes)
            ladder = (try? c.decode([DexLadderStep].self, forKey: .ladder)) ?? []
        }
    }

    /// 번들에서 읽는다. 없거나 깨졌으면 빈 목록 — 도감은 부가 기능이라
    /// 없다고 해서 상점·개봉이 멈추면 안 된다. 대신 로그에 남긴다.
    static func loadBundled() -> DexIndex {
        guard let url = AppResources.bundle?.url(forResource: "dex", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLog.write("dex index missing from bundle")
            return DexIndex(dexes: [])
        }
        return decode(data)
    }

    static func decode(_ data: Data) -> DexIndex {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            AppLog.write("dex index decode failed")
            return DexIndex(dexes: [])
        }

        var out: [Dex] = []
        var skipped = 0
        for row in payload.dexes {
            // 목표가 없는 도감은 완성 판정이 항상 참이 되어 보상을 즉시 준다. 테마는 구성원,
            // 세트는 마일스톤이 목표다. 티어가 범위를 벗어나면 별 표시와 보상표가 어긋난다.
            let hasGoal = row.kind == .set ? !row.milestones.isEmpty : !row.cards.isEmpty
            guard hasGoal, (1...Dex.maxTier).contains(row.tier) else {
                skipped += 1
                continue
            }
            out.append(Dex(id: row.id, kind: row.kind, name: row.name, blurb: row.blurb,
                           homeSet: row.homeSet, cards: row.cards, tier: row.tier,
                           medianPacks: row.medianPacks, medianTokens: row.medianTokens,
                           valueUSD: row.valueUSD, reward: row.reward,
                           milestones: row.milestones))
        }
        if skipped > 0 { AppLog.write("dex index: skipped \(skipped) malformed rows") }
        return DexIndex(dexes: out, ladder: payload.ladder)
    }
}
