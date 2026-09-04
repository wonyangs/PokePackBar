import Foundation

/// 카드 등급 — 국내 포켓몬 카드 커뮤니티가 쓰는 약칭이다.
/// 일본판 레어도 표기에서 온 말로, 영문판 등급명(Illustration Rare 등)보다 등급 감이 바로 온다.
///
/// 선언 순서가 곧 등급 순서다(낮은 것부터). 생성 스크립트(`build_card_index.py`)의
/// `TIER_ORDER` 와 일치해야 한다.
///
/// **칸은 나무위키 「포켓몬 카드 게임/레어도」 문서에 실린 등급만 둔다.** 우리가 등급이라고
/// 여길 만한 것을 골라 넣지 않는다 — 그렇게 했더니 LV.X·Prime·LEGEND·골드스타처럼 문서에
/// 없는 것이 칸으로 서고, 문서에 있는 BREAK 를 RR 에서 떼어 내는 잘못을 저질렀다.
/// (문서는 BREAK 를 RR 로 못박는다 — 「BREAK, EX, GX, V, ex 등 … 더블레어」.)
///
/// 그래서 영문판 등급명 39종이 이 칸들로 접힌다. 영문판에만 있는 이름(Rare Holo LV.X·
/// Rare Prime·LEGEND·Rare Holo Star)은 그 카드가 맡던 자리로 넣는다 — 앞의 셋은 그 시대의
/// 간판 홀로라 RR, 골드스타는 「박스당 0~1장」이라 SR 이다. 원본 이름은 카드 상세에
/// 그대로 적어 주므로(`L.rarityLabel`) 무엇인지는 잃지 않는다.
///
/// 아직 파는 세트에 카드가 없는 칸(CHR·MA·FUR·P)도 미리 둔다. 그 세트가 들어올 때 엉뚱한
/// 칸으로 새지 않게 하려는 것이고, 화면은 `presentTiers` 로 걸러 빈 칸을 보여 주지 않는다.
///
/// **이 사다리는 값 순서도 봉입률 순서도 아니다.** 커뮤니티가 등급을 늘어놓는 관례일 뿐이다 —
/// AR 은 팩의 7.7% 인데 ACE 는 0.6% 다. 목록 정렬은 시세를 쓴다.
enum CardTier: String, Codable, Sendable, CaseIterable {
    case energy = "E"           // 기본 에너지 — 등급 축이 아니라 별도 슬롯
    case common = "C"           // 커먼
    case uncommon = "U"         // 언커먼
    case rare = "R"             // 레어
    case promo = "P"            // 프로모
    case doubleRare = "RR"      // 더블레어 — 홀로레어·ex·GX·V·BREAK·LV.X·Prime·LEGEND
    case tripleRare = "RRR"     // 트리플레어 — VMAX·VSTAR·V-UNION
    case prismStar = "PR"       // 프리즘스타 — 썬&문 시대
    case amazing = "A"          // 어메이징레어 — 소드&실드 시대
    case radiant = "K"          // 찬란한 — 소드&실드 시대
    case characterRare = "CHR"  // 캐릭터레어 — 영문판 트레이너 갤러리
    case artRare = "AR"         // 아트레어
    case aceSpec = "ACE"        // ACE SPEC — 블랙&화이트, 스칼렛&바이올렛
    case superRare = "SR"       // 슈퍼레어 — 풀아트
    case shiny = "S"            // 샤이니 — 이로치. 팔데아의 운명 계열
    case shinyUltra = "SSR"     // 샤이니 울트라레어 — 이로치 풀아트
    case specialArtRare = "SAR" // 스페셜아트레어
    case shining = "SH"         // 빛나는 포켓몬 — 네오·썬&문. 위의 S(이로치)와 다른 등급이다
    case hyperRare = "HR"       // 하이퍼레어 — 레인보우
    case ultraRare = "UR"       // 울트라레어 — 금색 시크릿
    case blackWhiteRare = "BWR" // 블랙볼트·화이트플레어 전용
    case megaAttack = "MA"      // 메가어택레어 — 카툰풍 메가진화
    case megaUltraRare = "MUR"  // 메가 울트라레어 — 메가 에볼루션 이후
    case futureUltra = "FUR"    // 퓨처울트라레어 — 30th CELEBRATION 한정

    /// 등급 순위. 정렬과 개봉 순서가 이 값을 쓴다. 클수록 희귀하다.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// 요청한 등급이 그 세트에 없을 때 대신 찾아볼 순서.
    ///
    /// 세트마다 존재하는 등급이 다르다. 1999~2000년 세트에는 AR 이상이 아예 없고,
    /// 기념 세트에는 C·U 가 없다. 폴백이 없으면 그런 세트에서 팩 슬롯이 빈다.
    ///
    /// 배열을 등급마다 손으로 적지 않고 순위에서 만든다 — 등급을 하나 추가할 때
    /// 열 군데를 고쳐야 하면 반드시 하나가 어긋난다.
    var fallbackChain: [CardTier] {
        // 에너지는 대체하지 않는다. 없으면 호출부가 그 슬롯을 일반 카드로 채운다.
        guard self != .energy else { return [.energy] }
        let candidates = Self.allCases.filter { $0 != .energy }
        // 순위가 가까운 것부터. 같은 거리면 낮은 등급을 먼저 본다 —
        // 의도보다 희귀한 카드를 얹어 주는 쪽으로 새는 것을 막는다.
        return candidates.sorted {
            let d0 = abs($0.rank - rank), d1 = abs($1.rank - rank)
            return d0 != d1 ? d0 < d1 : $0.rank < $1.rank
        }
    }
}

struct CardEntry: Sendable, Identifiable {
    let id: String        // 예: "sv8pt5-1"
    let name: String
    let tier: CardTier
    let setID: String     // 카드 ID 의 첫 '-' 앞부분
    /// 원본 등급 이름("Rare Holo V", "Special Illustration Rare"…). 없는 카드는 nil 이다.
    ///
    /// `tier` 는 게임 규칙용으로 접은 10칸이라 「이 카드가 무슨 등급인가」에 답하지 못한다 —
    /// Radiant·ACE SPEC·BREAK·LV.X 가 모두 RRR 이다. 그걸 알려면 원본이 필요하다.
    /// 화면에 적을 때는 `L.rarityLabel` 이 커뮤니티 약칭으로 옮긴다.
    var rarity: String?

    /// 한국어 카드명. 아직 확인된 표기가 없는 카드는 nil 이다.
    ///
    /// 없으면 영문을 그대로 쓴다. 절반만 한국어인 이름("Team Rocket's 뮤츠 ex")은
    /// 영문보다 읽기 나쁘므로, 조립이 안 되면 아예 넣지 않는다.
    var nameKo: String?

    /// 화면에 쓸 이름. 한국어 표기가 있고 언어가 한국어일 때만 그것을 쓴다.
    func displayName(_ language: AppLanguage) -> String {
        language == .ko ? (nameKo ?? name) : name
    }
}

struct CardSet: Sendable, Identifiable {
    let id: String
    let name: String
    /// 시대(Base·Neo·XY·Scarlet & Violet…). 상점이 세트를 이걸로 묶는다.
    /// 옛 인덱스에는 없으므로 빈 문자열이면 「그 밖」으로 본다.
    var series: String = ""
    let released: String
    let cardCount: Int

    /// 발매 연도. 시대 줄에 「2023~2025」를 적는 데 쓴다.
    var year: String { String(released.prefix(4)) }
}

/// 앱에 번들된 카드 인덱스.
///
/// 카드 데이터를 런타임에 API 로 받지 않는다. 출처 API 는 성공률이 40% 안팎이고
/// 키 없이 하루 1,000회로 제한돼, 사용자마다 82페이지를 받게 하는 방식이 성립하지 않는다.
/// 미리 만든 인덱스를 함께 배포하고, 이미지만 필요할 때 받는다.
/// 한 시대에 속한 세트 묶음. 상점의 첫 화면이 이것을 늘어놓는다.
struct CardEra: Sendable, Identifiable {
    let name: String
    let sets: [CardSet]
    var id: String { name }

    /// 「2023 ~ 2025」. 한 해뿐이면 한 번만 적는다.
    var years: String {
        let all = sets.map(\.year).sorted()
        guard let first = all.first, let last = all.last else { return "" }
        return first == last ? first : "\(first) ~ \(last)"
    }

    /// 시대를 대표할 세트. 목록에 그림 한 장을 붙이는 데 쓴다 —
    /// 가장 최근 것이 그 시대를 가장 잘 알아보게 한다.
    var cover: CardSet? { sets.first }

    /// 최신 시대가 앞, 그 안에서도 최신 세트가 앞.
    ///
    /// **「그 밖」 칸을 만들지 않는다.** 시대 이름이 아니라 「분류를 못 했다」는 표시라,
    /// 목록에 서 있어도 무엇이 들었는지 읽히지 않는다. 시리즈를 모르는 세트는 제 이름으로
    /// 혼자 선다 — 그편이 적어도 무엇인지는 알려 준다. 인덱스를 만들 때 시리즈가 비면
    /// 빌드가 서므로(`build_card_index.py`) 여기까지 오는 일은 없어야 한다.
    static func group(_ sets: [CardSet]) -> [CardEra] {
        var bySeries: [String: [CardSet]] = [:]
        for set in sets {
            bySeries[set.series.nonEmpty ?? set.name, default: []].append(set)
        }
        return bySeries
            .map { CardEra(name: $0.key, sets: $0.value.sorted { $0.released > $1.released }) }
            .sorted { (a, b) in
                let (x, y) = (a.sets.first?.released ?? "", b.sets.first?.released ?? "")
                return x == y ? a.name < b.name : x > y
            }
    }
}

struct CardIndex: Sendable {

    let sets: [CardSet]
    let cards: [CardEntry]

    /// 세트 ID → 계층 → 그 계층의 카드 ID 목록. 팩 뽑기가 이 풀에서 고른다.
    let pools: [String: [CardTier: [String]]]

    /// 시대별로 묶은 세트. 최신 시대가 앞이고, 그 안에서는 최신 세트가 앞이다.
    ///
    /// 세트가 130개가 되면서 한 목록에 늘어놓을 수 없게 됐다. 묶는 일을 화면에서 매번 하면
    /// 그릴 때마다 돌므로 인덱스를 만들 때 한 번 세운다.
    let eras: [CardEra]

    /// 시세가 비싼 것부터 세워 둔 전체 목록. **읽을 때 정렬하지 않으려고 미리 세운다.**
    ///
    /// 컬렉션 화면이 매번 1,284장을 다시 정렬하고 있었다. 카드 그림이 하나 도착할 때마다
    /// 화면이 다시 그려지고 그때마다 정렬이 돌아, 컬렉션을 훑으면 덜컹거렸다. 정렬 기준인
    /// 시세는 실행 중에 바뀌지 않으므로 한 번만 세우면 된다.
    let cardsByValue: [CardEntry]

    /// 오리파 후보를 값 구간별로 미리 나눈 선반. 상점 화면은 이 값을 그대로 재사용한다.
    let oripaShelf: OripaConfig.Shelf

    /// 실제로 카드가 있는 등급만, 희귀한 것부터.
    ///
    /// 등급 칸에는 아직 파는 세트에 카드가 없는 것이 있다 — 메가어택레어처럼 곧 나올
    /// 세트를 위해 미리 자리를 만들어 둔 것들이다. 화면이 `allCases` 를 그대로 늘어놓으면
    /// 고르면 늘 빈 화면인 필터와 0/0 만 적힌 칸이 생긴다.
    let presentTiers: [CardTier]

    private let byID: [String: CardEntry]
    private let bySetID: [String: CardSet]

    func card(_ id: String) -> CardEntry? { byID[id] }

    /// 그 세트에 든 카드 전부. **세트 도감의 목표가 이 목록의 크기다.**
    ///
    /// `pools` 를 등급별로 쪼개 두었으므로 합쳐 준다. 도감 진행을 잴 때마다 부르므로
    /// 정렬은 하지 않는다 — 세는 것이 목적이고 순서는 쓰이지 않는다.
    func cards(inSet setID: String) -> [String] {
        (pools[setID] ?? [:]).values.flatMap { $0 }
    }
    func set(_ id: String) -> CardSet? { bySetID[id] }

    /// 이 세트의 팩 시대. 팩 구성과 봉입률이 여기서 갈린다.
    ///
    /// 세트를 훑어 찾지 않는다 — 팩 하나를 뜯을 때마다, 확률표를 그릴 때마다 불리는 자리라
    /// 122개를 훑으면 그만큼 쌓인다.
    func era(_ setID: String) -> PackEra {
        PackEra.of(released: bySetID[setID]?.released ?? "")
    }

    var setIDs: [String] { sets.map(\.id) }

    // MARK: 로딩

    private struct Payload: Decodable {
        struct SetDTO: Decodable {
            let id: String
            let name: String
            let series: String?
            let released: String
            let cardCount: Int
        }
        let version: Int
        let sets: [SetDTO]
        /// [카드ID, 이름, 계층, 등급번호]. 등급번호는 `rarities` 의 색인이다.
        /// 판번호마다 칸이 늘 수 있어 문자열 배열로 받고 마지막 칸은 있으면 쓴다.
        let cards: [[JSONValue]]
        let rarities: [String]?
    }

    /// 카드 행이 문자열과 숫자를 섞어 담는다. 한 칸만 숫자라 전용 타입을 두지 않는다.
    enum JSONValue: Decodable {
        case string(String)
        case int(Int)

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let n = try? c.decode(Int.self) { self = .int(n); return }
            self = .string(try c.decode(String.self))
        }

        var text: String? { if case let .string(s) = self { return s }; return nil }
        var number: Int? { if case let .int(n) = self { return n }; return nil }
    }

    /// 번들에서 읽는다. 인덱스가 없거나 깨졌으면 nil — 호출부가 실패를 드러내야 한다.
    /// 조용히 빈 인덱스를 돌려주면 상점이 텅 빈 이유를 알 수 없다.
    /// 번들 인덱스. 메뉴바·팝오버·보너스 팩이 같은 것을 쓴다 —
    /// 호출부마다 읽으면 같은 JSON 을 여러 번 파싱한다.
    static let shared: CardIndex? = loadBundled()

    static func loadBundled() -> CardIndex? {
        guard let url = AppResources.bundle?.url(forResource: "card-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLog.write("card index missing from bundle")
            return nil
        }
        return decode(data, korean: loadKoreanNames())
    }

    /// 한국어 카드명 표. 없으면 빈 표 — 이름이 영문으로 나올 뿐 앱은 그대로 돈다.
    static func loadKoreanNames() -> [String: String] {
        guard let url = AppResources.bundle?.url(forResource: "card-names-ko", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(KoreanNames.self, from: data) else {
            AppLog.write("korean card names missing from bundle")
            return [:]
        }
        return payload.names
    }

    private struct KoreanNames: Decodable {
        let version: Int
        let names: [String: String]
    }

    /// 값이 비싼 것부터. **보유 여부는 순서에 넣지 않는다.**
    ///
    /// 가진 카드를 통째로 위로 올리면 값의 사다리가 두 토막으로 끊겨, 전체 중 내가 어디까지
    /// 왔는지도 위쪽에 무엇이 아직 없는지도 알 수 없다. 가진 것만 보려면 목록을 거른다.
    ///
    /// 등급으로 세우지 않는 이유: 순서가 시장과 어긋난다. 1999년 커먼 한 장이 최신 SR 보다
    /// 비싸고, 같은 등급 안에서도 40배가 갈린다.
    static func byValue(_ entries: [CardEntry],
                        prices: CardPrices? = CardPrices.shared) -> [CardEntry] {
        // **값을 먼저 뽑아 두고 정렬한다.** 비교 안에서 시세를 조회하면 한 번 정렬에
        // 사전 조회가 50만 번 일어난다 — 18,327장에서 122ms 였다. 장당 한 번만 조회하면
        // 그 일이 사라진다.
        let keyed = entries.map {
            (price: MarketEconomy.usd(cardID: $0.id, prices: prices),
             rank: $0.tier.rank, entry: $0)
        }
        return keyed.sorted { a, b in
            if a.price != b.price { return a.price > b.price }
            if a.rank != b.rank { return a.rank > b.rank }
            return a.entry.id < b.entry.id                      // 나머지는 안정적으로
        }.map(\.entry)
    }

    static func decode(_ data: Data, korean: [String: String] = [:]) -> CardIndex? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            AppLog.write("card index decode failed")
            return nil
        }

        var entries: [CardEntry] = []
        entries.reserveCapacity(payload.cards.count)
        var skipped = 0
        let rarities = payload.rarities ?? []
        for row in payload.cards {
            // [ID, 이름, 계층] 세 칸이어야 한다. 계층 문자열이 알 수 없는 값이면 건너뛴다 —
            // 생성 스크립트와 앱의 계층 정의가 어긋난 것이므로 조용히 섞어 넣지 않는다.
            guard row.count >= 3, let id = row[0].text, let name = row[1].text,
                  let tier = row[2].text.flatMap(CardTier.init(rawValue:)) else {
                skipped += 1; continue
            }
            guard let dash = id.firstIndex(of: "-") else { skipped += 1; continue }
            // 네 번째 칸은 등급 표의 번호다. 옛 인덱스에는 없다.
            let rarity = row.count >= 4 ? row[3].number.flatMap { rarities.indices.contains($0)
                                                                 ? rarities[$0] : nil } : nil
            entries.append(CardEntry(id: id, name: name, tier: tier,
                                     setID: String(id[id.startIndex..<dash]),
                                     rarity: rarity?.nonEmpty,
                                     nameKo: korean[id]))
        }
        if skipped > 0 { AppLog.write("card index: skipped \(skipped) malformed rows") }

        var pools: [String: [CardTier: [String]]] = [:]
        for e in entries { pools[e.setID, default: [:]][e.tier, default: []].append(e.id) }

        let sets = payload.sets.map {
            CardSet(id: $0.id, name: $0.name, series: $0.series ?? "",
                    released: $0.released, cardCount: $0.cardCount)
        }
        let present = Set(entries.map(\.tier))
        return CardIndex(sets: sets, cards: entries, pools: pools,
                         eras: CardEra.group(sets),
                         cardsByValue: byValue(entries),
                         oripaShelf: OripaConfig.shelf(cards: entries),
                         presentTiers: CardTier.allCases.reversed().filter(present.contains),
                         byID: Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }),
                         bySetID: Dictionary(sets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }))
    }
}

/// 카드 이미지 주소를 만드는 곳. 출처를 한 곳으로 모아 둔다.
///
/// 오브젝트 이름을 카드 ID 로 통일했으므로 경로를 카드 ID 에서 유도할 수 있다.
/// 원본 CDN 은 같은 카드의 파일명이 카드 번호와도 ID 와도 어긋나는 경우가 있어
/// 경로를 추론할 수 없었다. 업로드 때 이름을 통일해 그 문제를 없앴다.
enum CardImageSource {
    /// 이미지 버킷의 공개 기본 주소. 설정으로 바꿀 수 있게 두어,
    /// 공개 배포판에서 다른 출처로 전환할 여지를 남긴다.
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "cardImageBaseURL")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? defaultBaseURL
    }

    /// 카드 이미지 버킷의 공개 기본 주소. 오브젝트 이름을 카드 ID 로 통일해 두었으므로
    /// 여기에 `/cards/<세트ID>/<카드ID>.webp` 를 붙이면 주소가 완성된다.
    static let defaultBaseURL = "https://zaoosaaiyamnnuhhnnxt.supabase.co/storage/v1/object/public"

    /// 세트의 부스터 팩 아트. 카드와 같은 버킷의 packs/ 아래에 세트 ID 로 둔다.
    static func packURL(setID: String) -> URL? {
        guard let base = trimmedBase else { return nil }
        return URL(string: "\(base)/cards/packs/\(setID).webp")
    }

    private static var trimmedBase: String? {
        let base = baseURL
        guard !base.isEmpty else { return nil }
        return base.hasSuffix("/") ? String(base.dropLast()) : base
    }

    static func url(cardID: String, hires: Bool) -> URL? {
        guard let base = trimmedBase, let dash = cardID.firstIndex(of: "-") else { return nil }
        let setID = String(cardID[cardID.startIndex..<dash])
        let suffix = hires ? "_hires" : ""
        return URL(string: "\(base)/cards/\(setID)/\(cardID)\(suffix).webp")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
