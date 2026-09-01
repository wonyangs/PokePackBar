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

struct DexReward: Codable, Sendable, Equatable {
    /// 수령 시 주는 팩. 도감의 `homeSet` 팩이다.
    let packs: Int
    /// 영구 혜택. 여러 개일 수 있다 — 최고 난도 조합은 눈에 보이는 것 하나와
    /// 패시브 하나를 함께 준다.
    let perks: [DexPerk]
}

/// 한국어 정본 + 영어. 카드 팩 소개(`packBlurb`)와 같은 방식이다 —
/// 도감 이름은 문안이 길고 수가 계속 늘어나서 6개 언어를 전부 유지할 수 없다.
struct DexText: Codable, Sendable, Equatable {
    let ko: String
    let en: String

    func text(_ language: AppLanguage) -> String { language == .ko ? ko : en }
}

/// 카드 몇 장을 묶은 조합.
struct Dex: Sendable, Identifiable, Equatable {
    let id: String
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

    /// 난이도 상한. 표시(별)와 보상표가 이 범위를 벗어나지 않는다.
    static let maxTier = 5
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
    static func total(completed: Set<String>, dexes: [Dex]) -> DexPerks {
        var perks = DexPerks()
        for dex in dexes where completed.contains(dex.id) {
            for perk in dex.reward.perks {
                switch perk.kind {
                case .tokenGain:    perks.tokenGain += perk.value
                case .packDiscount: perks.packDiscount += perk.value
                case .dustBonus:    perks.dustBonus += perk.value
                case .hitOdds:      perks.hitOdds += perk.value
                }
            }
        }
        return perks.clamped()
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

    private let byID: [String: Dex]

    func dex(_ id: String) -> Dex? { byID[id] }

    /// 이 카드가 들어가는 도감들. 카드 상세에서 "어디에 쓰이는 카드인가" 를 보여줄 때 쓴다.
    func dexes(containing cardID: String) -> [Dex] {
        dexes.filter { $0.cards.contains(cardID) }
    }

    init(dexes: [Dex]) {
        self.dexes = dexes
        byID = Dictionary(dexes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: 로딩

    private struct Payload: Decodable {
        struct DexDTO: Decodable {
            let id: String
            let name: DexText
            let blurb: DexText
            let homeSet: String
            let cards: [String]
            let tier: Int
            let medianPacks: Int
            let medianTokens: Int
            let valueUSD: Double
            let reward: DexReward
        }
        let version: Int
        let dexes: [DexDTO]
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
            // 구성원이 없는 도감은 완성 판정이 항상 참이 되어 보상을 즉시 준다.
            // 티어가 범위를 벗어나면 별 표시와 보상표가 어긋난다. 둘 다 건너뛴다.
            guard !row.cards.isEmpty, (1...Dex.maxTier).contains(row.tier) else {
                skipped += 1
                continue
            }
            out.append(Dex(id: row.id, name: row.name, blurb: row.blurb, homeSet: row.homeSet,
                           cards: row.cards, tier: row.tier, medianPacks: row.medianPacks,
                           medianTokens: row.medianTokens, valueUSD: row.valueUSD,
                           reward: row.reward))
        }
        if skipped > 0 { AppLog.write("dex index: skipped \(skipped) malformed rows") }
        return DexIndex(dexes: out)
    }
}
