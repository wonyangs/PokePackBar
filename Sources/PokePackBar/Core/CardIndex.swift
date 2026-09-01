import Foundation

/// 카드 등급 — 국내 포켓몬 카드 커뮤니티가 쓰는 약칭이다.
/// 일본판 레어도 표기에서 온 말로, 영문판 등급명(Illustration Rare 등)보다 등급 감이 바로 온다.
///
/// 선언 순서가 곧 등급 순서다(낮은 것부터). 생성 스크립트(`build_card_index.py`)의
/// `TIER_ORDER` 와 일치해야 한다.
enum CardTier: String, Codable, Sendable, CaseIterable {
    case energy = "E"           // 기본 에너지 — 등급 축이 아니라 별도 슬롯
    case common = "C"           // 커먼
    case uncommon = "U"         // 언커먼
    case rare = "R"             // 레어
    case doubleRare = "RR"      // 더블레어 — 홀로레어·ex·V 계열
    case tripleRare = "RRR"     // 트리플레어 — VMAX·VSTAR·K·ACE
    case artRare = "AR"         // 아트레어
    case superRare = "SR"       // 슈퍼레어 — 풀아트
    case specialArtRare = "SAR" // 스페셜아트레어
    case ultraRare = "UR"       // 울트라레어 — 골드·레인보우·시크릿

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
    let released: String
    let cardCount: Int
}

/// 앱에 번들된 카드 인덱스.
///
/// 카드 데이터를 런타임에 API 로 받지 않는다. 출처 API 는 성공률이 40% 안팎이고
/// 키 없이 하루 1,000회로 제한돼, 사용자마다 82페이지를 받게 하는 방식이 성립하지 않는다.
/// 미리 만든 인덱스를 함께 배포하고, 이미지만 필요할 때 받는다.
struct CardIndex: Sendable {

    let sets: [CardSet]
    let cards: [CardEntry]

    /// 세트 ID → 계층 → 그 계층의 카드 ID 목록. 팩 뽑기가 이 풀에서 고른다.
    let pools: [String: [CardTier: [String]]]

    /// 시세가 비싼 것부터 세워 둔 전체 목록. **읽을 때 정렬하지 않으려고 미리 세운다.**
    ///
    /// 컬렉션 화면이 매번 1,284장을 다시 정렬하고 있었다. 카드 그림이 하나 도착할 때마다
    /// 화면이 다시 그려지고 그때마다 정렬이 돌아, 컬렉션을 훑으면 덜컹거렸다. 정렬 기준인
    /// 시세는 실행 중에 바뀌지 않으므로 한 번만 세우면 된다.
    let cardsByValue: [CardEntry]

    private let byID: [String: CardEntry]

    func card(_ id: String) -> CardEntry? { byID[id] }
    func set(_ id: String) -> CardSet? { sets.first { $0.id == id } }

    var setIDs: [String] { sets.map(\.id) }

    // MARK: 로딩

    private struct Payload: Decodable {
        struct SetDTO: Decodable {
            let id: String
            let name: String
            let released: String
            let cardCount: Int
        }
        let version: Int
        let sets: [SetDTO]
        let cards: [[String]]   // [카드ID, 이름, 계층]
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
        entries.sorted { a, b in
            let priceA = MarketEconomy.usd(cardID: a.id, prices: prices)
            let priceB = MarketEconomy.usd(cardID: b.id, prices: prices)
            if priceA != priceB { return priceA > priceB }
            if a.tier.rank != b.tier.rank { return a.tier.rank > b.tier.rank }
            return a.id < b.id                                  // 나머지는 안정적으로
        }
    }

    static func decode(_ data: Data, korean: [String: String] = [:]) -> CardIndex? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            AppLog.write("card index decode failed")
            return nil
        }

        var entries: [CardEntry] = []
        entries.reserveCapacity(payload.cards.count)
        var skipped = 0
        for row in payload.cards {
            // [ID, 이름, 계층] 세 칸이어야 한다. 계층 문자열이 알 수 없는 값이면 건너뛴다 —
            // 생성 스크립트와 앱의 계층 정의가 어긋난 것이므로 조용히 섞어 넣지 않는다.
            guard row.count >= 3, let tier = CardTier(rawValue: row[2]) else { skipped += 1; continue }
            let id = row[0]
            guard let dash = id.firstIndex(of: "-") else { skipped += 1; continue }
            entries.append(CardEntry(id: id, name: row[1], tier: tier,
                                     setID: String(id[id.startIndex..<dash]),
                                     nameKo: korean[id]))
        }
        if skipped > 0 { AppLog.write("card index: skipped \(skipped) malformed rows") }

        var pools: [String: [CardTier: [String]]] = [:]
        for e in entries { pools[e.setID, default: [:]][e.tier, default: []].append(e.id) }

        let sets = payload.sets.map {
            CardSet(id: $0.id, name: $0.name, released: $0.released, cardCount: $0.cardCount)
        }
        return CardIndex(sets: sets, cards: entries, pools: pools,
                         cardsByValue: byValue(entries),
                         byID: Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }))
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
