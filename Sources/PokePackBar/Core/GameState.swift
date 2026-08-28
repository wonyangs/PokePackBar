import Foundation

/// 저장되는 게임 상태 전부. 단일 JSON 파일로 영속된다.
///
/// 컴패니언(알·진화·도감·아이템)을 걷어낸 자리에 카드 게임 상태가 들어간다.
/// 토큰 장부 관련 필드는 기존 구조를 그대로 물려받았다 — 프로바이더별 적립 기준을
/// 다루는 부분은 실제 결함을 고쳐 온 산물이라 재설계하지 않는다.
struct GameState: Codable, Sendable {

    // MARK: 토큰 장부 (재화)

    /// 설치 기준선이 잡혔는가. 실제 사용량 데이터가 처음 도착한 시점에 잡는다 —
    /// 그 전의 과거 사용량은 재화로 세지 않는다.
    var installBaselineSet = false

    /// 설치 이후 누적 사용 토큰. 감소하지 않는다.
    var usedSinceInstall = 0

    /// 중복 카드를 갈아 돌려받은 토큰 누적.
    /// 지출과 따로 센다 — 사용량 통계(`usedSinceInstall`)를 건드리지 않으면서
    /// 잔액만 늘리려면 별도 항목이 있어야 한다.
    var refundedTokens = 0

    /// 갈아 없앤 카드 누적 장수. 통계용.
    var cardsDisenchanted = 0

    /// 상점에서 쓴 토큰 누적. 쓸 수 있는 재화 = `usedSinceInstall − spentTokens + refundedTokens`.
    /// 구매는 이 값만 올린다 — 누적 사용량은 통계이므로 되감지 않는다.
    var spentTokens = 0

    /// 오늘 사용량 적립 기준값 — 프로바이더별로 독립 관리한다.
    ///
    /// `nil` 은 아직 첫 유효 관측으로 seed 되지 않았다는 뜻이다. 빈 map(이미 seed 된 뒤
    /// 오늘 보고한 프로바이더가 없는 정상 상태)과 반드시 구분해야 하므로 옵셔널로 둔다.
    /// 키는 `UsageProvider.id` 를 그대로 쓴다.
    var claimedTodayTokensByProvider: [String: Int]? = nil

    /// 마지막으로 적립을 처리한 날짜(`yyyy-MM-dd`). 날짜가 바뀌면 기준값을 다시 연다.
    var lastDate = ""

    // MARK: 카드 게임

    /// 미개봉 팩 보유량 — 세트 ID → 개수.
    var packs: [String: Int] = [:]

    /// 수집한 카드 — 카드 ID → 보유 장수. 같은 카드를 여러 장 가질 수 있다.
    var cards: [String: Int] = [:]

    /// 개봉한 팩 누적 개수. 통계용.
    var packsOpened = 0

    // MARK: 조합 도감

    /// 보상을 수령한 도감 id. **영구 기록이다** — 나중에 도감 구성이 바뀌어도 이미 준 혜택을
    /// 회수하지 않고, 보상을 두 번 주지 않는 근거도 이 목록이다.
    ///
    /// 완성 여부 자체는 저장하지 않는다. 보유 카드에서 매번 계산하는 편이 정확하다 —
    /// 도감 기능이 생기기 전에 이미 모아 둔 카드도 그래야 완성으로 잡힌다.
    var claimedDex: [String] = []

    /// 세트별 천장 카운터 — 레어 이상 칸에서 연속으로 레어만 나온 횟수.
    ///
    /// 영속이어야 한다. 재시작마다 0 으로 돌아가면 보장이 사실상 없는 것과 같다.
    var packPity: [String: Int] = [:]

    /// 도감 혜택(`tokenGain`)으로 추가 적립된 토큰 누적.
    ///
    /// `usedSinceInstall` 에 배수를 곱하지 않는다. 그 값은 실제 사용량이라
    /// 곱해 버리면 화면에 보이는 사용량이 거짓이 된다. 잔액에만 더한다.
    var perkTokens = 0

    // MARK: 보너스 팩 (한도 달성 보상)

    /// 한도 창별 지급 상태(창 key → 지급 여부). 영속이어야 한다 —
    /// 재시작마다 같은 창에서 다시 지급되는 것을 막는다.
    /// 창이 100% 아래로 내려가면 항목이 제거되어 다시 무장된다.
    var packGrantTier: [String: Int] = [:]

    /// 보너스 팩 기능의 첫 실행 시드 완료 여부.
    /// 설치 직후 이미 100% 였던 창에 소급 지급하지 않기 위해 필요하다.
    var packGrantSeeded = false

    // MARK: 설정

    var language: AppLanguage = .systemDefault   // 신규 설치 = 시스템 로케일

    init() {}

    /// 관대한 디코딩 — 누락 키와 타입 불일치를 필드별로 흡수한다.
    ///
    /// 한 필드가 깨졌다고 상태 전체(수집한 카드)를 날리지 않기 위한 것이다.
    /// 최상위가 JSON 객체가 아니면 디코딩을 실패시켜 호출부의 손상 복구 경로로 넘긴다.
    /// 저장 키 — `claimedDex` 는 예전에 `completedDex` 였다. 옛 세이브를 읽으려면 둘 다 필요하다.
    private enum LegacyKeys: String, CodingKey { case completedDex }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        installBaselineSet = value(.installBaselineSet, false)
        usedSinceInstall = value(.usedSinceInstall, 0)
        spentTokens = value(.spentTokens, 0)
        refundedTokens = value(.refundedTokens, 0)
        cardsDisenchanted = value(.cardsDisenchanted, 0)
        // 옵셔널은 위 헬퍼로 다룰 수 없다 — 값 없음과 디코딩 실패를 구분해야 한다.
        claimedTodayTokensByProvider = try? c.decodeIfPresent([String: Int].self,
                                                             forKey: .claimedTodayTokensByProvider)
        lastDate = value(.lastDate, "")
        packs = value(.packs, [:])
        cards = value(.cards, [:])
        packsOpened = value(.packsOpened, 0)
        // 이전 이름(completedDex)으로 저장된 값도 읽는다.
        var claimed = value(.claimedDex, [String]())
        if claimed.isEmpty, let legacy = try? decoder.container(keyedBy: LegacyKeys.self),
           let previous = try? legacy.decode([String].self, forKey: .completedDex) {
            claimed = previous
        }
        claimedDex = claimed
        perkTokens = value(.perkTokens, 0)
        packPity = value(.packPity, [:])
        packGrantTier = value(.packGrantTier, [:])
        packGrantSeeded = value(.packGrantSeeded, false)
        language = value(.language, AppLanguage.systemDefault)
    }
}
