import Foundation
import Observation

/// 보너스 팩 판정 입력 — 프로바이더 무관 한도 창 1개.
///
/// 기존 사탕 지급 경로가 쓰던 창 추상을 카드 게임 이름으로 옮긴 것이다.
/// 휘발 필드(리셋 시각 등)를 key 에 넣지 않는다 — 창을 안정적으로 식별해야
/// "이미 지급했는지" 판정이 재시작을 건너서도 유지된다.
struct BonusWindow: Sendable {
    let key: String
    let name: String
    let kind: WindowClass
    let utilization: Double   // 0~100+

    /// 이 창의 **판** — 누구의 창인지와 언제 초기화되는지를 합친 값. 한 판에 한 번만 지급한다.
    ///
    /// 계정을 바꾸면 사용률이 0% 로 떨어진다. 그것을 「창이 초기화됐다」로 읽으면 계정을
    /// 오가는 것만으로 같은 창이 몇 번이고 지급된다. 판이 있으면 둘을 구분할 수 있다.
    ///
    /// 빈 문자열은 **구분할 수 없다**는 뜻이다(계정도 초기화 시각도 못 얻은 프로바이더).
    /// 그런 창만 예전 규칙 — 100% 아래로 내려가면 다시 무장 — 에 기댄다.
    let instance: String

    init(key: String, name: String, kind: WindowClass, utilization: Double, instance: String = "") {
        self.key = key
        self.name = name
        self.kind = kind
        self.utilization = utilization
        self.instance = instance
    }
}

/// 보너스로 줄 수 있는 세트 하나 — id 와 **정가**. 도감 할인·쿠폰을 뺀 값이다.
/// 할인된 값으로 개수를 세면 혜택이 많은 사람일수록 보너스가 커진다.
struct BonusSet: Sendable, Equatable {
    let id: String
    let price: Int
}

/// 보너스 팩 지급 1건. 순수 판정 결과라 부수효과와 분리해 검증할 수 있다.
struct PackGrant: Equatable, Sendable {
    let windowKey: String
    let windowName: String
    let setID: String
    let count: Int
}

/// 수령 결과. 화면이 「무엇을 받았는지」를 알릴 때 쓴다.
struct DexClaim: Sendable, Equatable {
    let dex: Dex
    let step: Int
    let reward: DexReward
    /// 확정 카드로 받은 카드. 없으면 nil.
    let card: String?
}

/// 이번 개봉으로 다 모인 도감 1건. 개봉 결과 화면이 이걸 받아 알린다.
/// 보상은 여기서 주지 않는다 — 수령은 도감 화면에서 사용자가 직접 누른다.
struct DexCompletion: Equatable, Sendable, Identifiable {
    let dexID: String
    let name: DexText
    let tier: Int

    var id: String { dexID }
}

/// 재화(토큰) 지갑과 카드·팩 보유량을 관리한다.
///
/// 사용량 적립 로직은 기존 컴패니언 저장소의 것을 그대로 옮겼다. 프로바이더별 장부,
/// 날짜 전환, 역행 시 개별 rebase 는 실제 결함을 고쳐 온 산물이라 재설계하지 않는다.
/// 컴패니언 관련 분기(알 인큐베이션·진화 진행)만 걷어냈다.
@MainActor
@Observable
final class WalletStore {

    private(set) var state = GameState()
    private let fileURL: URL

    /// 개봉 결과 등 UI 가 한 번만 소비해야 하는 알림. nil 이면 표시할 것이 없다.
    var lastGrant: PackGrant?
    func consumeGrant() { lastGrant = nil }

    /// 조합 도감 목록. 테스트가 갈아 끼울 수 있게 주입받는다.
    let dexes: [Dex]
    /// 완성 수 계단. 영구 혜택의 주인이다.
    let ladder: [DexLadderStep]

    /// 완성한 도감에서 나온 영구 혜택.
    ///
    /// 매번 다시 모으지 않고 캐시한다 — 팩 가격과 확률표가 화면을 그릴 때마다 읽고,
    /// 사용량 적립도 매 새로고침마다 읽는다.
    private(set) var perks: DexPerks = .none

    init(fileURL: URL? = nil, dexes: [Dex]? = nil, ladder: [DexLadderStep]? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        let bundled = (dexes == nil || ladder == nil) ? DexIndex.loadBundled() : nil
        self.dexes = dexes ?? bundled?.dexes ?? []
        self.ladder = ladder ?? bundled?.ladder ?? []
        load()
        refreshPerks()
    }

    /// 영구 혜택을 다시 모은다 — 도감 + 계단.
    ///
    /// **쿠폰은 여기 합치지 않는다.** 쿠폰은 세트가 정해져 있어서 `DexPerks` 로는 표현할 수
    /// 없다 — 합쳐 두면 어느 세트에나 걸려서 「가장 비싼 팩을 노리고 돈을 모으는 것이 최적」이
    /// 된다. 팩값은 `packPrice(setID:)` 가 쿠폰까지 보고 계산한다.
    private func refreshPerks() {
        perks = DexPerks.total(completed: claimedDexIDs, dexes: dexes, ladder: ladder)
    }

    static func defaultURL() -> URL {
        // 상태 파일 위치. `PPB_STATE_DIR` 환경변수가 있으면 그 디렉토리를 쓴다 — 개발·QA 격리용.
        // 공백만 있는 값은 무시한다(상대경로로 해석되는 것 방지).
        let override = (ProcessInfo.processInfo.environment["PPB_STATE_DIR"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dir: URL
        if !override.isEmpty {
            dir = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PokePackBar")
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("game-state.json")
    }

    var l: L { L(state.language) }
    var language: AppLanguage { state.language }
    func setLanguage(_ lang: AppLanguage) { state.language = lang; save() }

    // MARK: 재화

    /// 상점에서 쓸 수 있는 토큰 = 누적 사용량 − 지출 + 갈아 돌려받은 것 + 도감 혜택 적립분.
    var availableTokens: Int {
        max(0, state.usedSinceInstall - state.spentTokens + state.refundedTokens + state.perkTokens)
    }

    var usedSinceInstall: Int { state.usedSinceInstall }

    /// 설치 기준선이 아직 안 잡혔는가 — 사용량 데이터가 한 번도 도착하지 않은 상태.
    /// UI 가 "아직 0" 과 "측정 시작 전" 을 구분해 안내할 수 있게 노출한다.
    var awaitingFirstUsage: Bool { !state.installBaselineSet }

    /// 재화를 차감한다. 잔액이 부족하면 아무것도 하지 않고 false.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, availableTokens >= amount else { return false }
        state.spentTokens += amount
        save()
        return true
    }

    // MARK: 사용량 적립

    /// 사용량 갱신. 앱 델리게이트가 매 새로고침마다 호출한다.
    ///
    /// `hasUsageData` 는 표시용 스냅샷 존재 여부이고, 전달된 map 은 오늘 날짜가 확인된
    /// 프로바이더 데이터만 담는다. 오래된 스냅샷이나 오늘 값이 없는 갱신은
    /// 장부 기준점을 움직일 관측으로 취급하지 않는다.
    func update(todayTokensByProvider: [String: Int], todayDate: String, hasUsageData: Bool) {
        let hasCurrentProviderData = hasUsageData && !todayTokensByProvider.isEmpty

        if !state.installBaselineSet {
            // 설치 기준선 — 실제 데이터가 도착한 시점의 오늘 값을 기준으로 잡는다.
            // 그 전의 과거 사용량은 재화로 세지 않는다.
            guard hasCurrentProviderData else { return }
            state.installBaselineSet = true
            state.claimedTodayTokensByProvider = todayTokensByProvider
            state.lastDate = todayDate
            AppLog.write("wallet install baseline set date=\(todayDate)")
            save()
            return
        }

        // 유효한 사용량이 있는 갱신만 장부를 움직인다. 빈 갱신으로 날짜·장부를 건드리면
        // 다음 정상 스냅샷을 당일 전체 신규 사용량으로 오인할 수 있다.
        guard hasCurrentProviderData else { return }

        let dateChanged = todayDate != state.lastDate

        if state.claimedTodayTokensByProvider == nil {
            // 아직 프로바이더별로 분해된 기준값이 없다. 첫 유효 관측을 기준점으로만 저장하고
            // 과거 사용량을 소급 지급하지 않는다.
            state.claimedTodayTokensByProvider = todayTokensByProvider
            state.lastDate = todayDate
            AppLog.write("wallet ledger seeded date=\(todayDate) providers=\(todayTokensByProvider.keys.sorted().joined(separator: ","))")
        } else if dateChanged {
            // 일자별 스냅샷은 서로 비교할 수 없다. 새 날짜에는 현재 누적값 전체를 그 날짜의
            // 사용량으로 적립한다.
            //
            // 이전 날짜에 알려졌던 프로바이더가 첫 새로고침에서 빠질 수 있다(오늘 데이터 없음,
            // 오래된 응답, 일시 실패). 그 프로바이더를 장부에서 아예 제거하면 같은 날짜에
            // 복구될 때 현재 누적값을 "이미 적립한 값" 으로 seed 해 사용량이 누락된다.
            // 그래서 알려진 프로바이더의 새 날짜 기준을 0 으로 열어 둔다.
            state.lastDate = todayDate
            var newLedger = Dictionary(uniqueKeysWithValues:
                state.claimedTodayTokensByProvider!.keys.map { ($0, 0) })
            for (providerID, current) in todayTokensByProvider {
                newLedger[providerID] = current
            }
            state.claimedTodayTokensByProvider = newLedger
            let delta = todayTokensByProvider.values.reduce(0, +)
            if delta > 0 { accrue(delta) }
        } else {
            var ledger = state.claimedTodayTokensByProvider ?? [:]
            var delta = 0
            for (providerID, current) in todayTokensByProvider {
                guard let previous = ledger[providerID] else {
                    // 새로 관측된 프로바이더의 과거 로그를 소급하지 않는다. 다음 갱신부터
                    // 증가분을 추적할 수 있도록 현재 값을 seed 한다.
                    ledger[providerID] = current
                    continue
                }
                if current < previous {
                    // 전체 합계가 아니라 해당 프로바이더의 줄만 rebase 한다. 다른 프로바이더가
                    // 이번 갱신에서 보고하지 않았다면 map 에 줄 자체가 없으므로 기준값을 건드리지 않는다.
                    ledger[providerID] = current
                    AppLog.write("wallet usage regression provider=\(providerID) date=\(todayDate) previous=\(previous) current=\(current) drop=\(previous - current) — rebased provider ledger")
                    continue
                }
                delta += current - previous
                ledger[providerID] = current
            }
            state.claimedTodayTokensByProvider = ledger
            if delta > 0 { accrue(delta) }
        }

        save()
    }

    /// 사용량 증가분을 장부에 넣는다. 도감 혜택이 있으면 그만큼 별도로 더 쌓는다.
    ///
    /// `usedSinceInstall` 에 배수를 곱하지 않는 이유: 그 값은 실제 사용량이라
    /// 곱해 버리면 사용량 표시가 거짓이 된다. 잔액에만 반영한다.
    private func accrue(_ delta: Int) {
        state.usedSinceInstall += delta
        guard perks.tokenGain > 0 else { return }
        let bonus = Int((Double(delta) * perks.tokenGain).rounded())
        if bonus > 0 { state.perkTokens += bonus }
    }

    // MARK: 팩 보유량

    func packCount(setID: String) -> Int { state.packs[setID] ?? 0 }

    var totalPackCount: Int { state.packs.values.reduce(0, +) }

    /// 보유한 팩 — 개수가 0 이 아닌 것만, 세트 ID 순.
    var ownedPacks: [(setID: String, count: Int)] {
        state.packs.filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { (setID: $0.key, count: $0.value) }
    }

    func addPack(setID: String, count: Int = 1) {
        guard count > 0 else { return }
        state.packs[setID, default: 0] += count
        save()
    }

    /// 팩 1개를 소비한다. 보유량이 없으면 false — 호출부는 개봉을 진행하지 않는다.
    @discardableResult
    func consumePack(setID: String) -> Bool {
        let owned = state.packs[setID] ?? 0
        guard owned > 0 else { return false }
        if owned == 1 { state.packs.removeValue(forKey: setID) } else { state.packs[setID] = owned - 1 }
        state.packsOpened += 1
        save()
        return true
    }

    // MARK: 카드 갈기

    /// 갈 수 있는 장수 — 보유분에서 한 장은 남긴다. 컬렉션에서 사라지면 안 된다.
    func spareCount(_ cardID: String) -> Int { max(0, cardCount(cardID) - 1) }

    /// 중복분을 판다. 받은 액수를 반환하고, 팔 것이 없으면 0.
    ///
    /// 시세 그대로 값을 쳐 준다(도감 판매 추가금이 있으면 그만큼 더). 마지막 한 장은
    /// 남긴다 — 수집한 카드가 컬렉션에서 없어지는 것은 되돌릴 수 없고, 실수로 그렇게 되면
    /// 잃은 것이 크다.
    @discardableResult
    func sellSpares(cardID: String, tier: CardTier, count: Int) -> Int {
        let spare = spareCount(cardID)
        let amount = min(max(count, 0), spare)
        guard amount > 0 else { return 0 }

        state.cards[cardID] = cardCount(cardID) - amount
        let refund = CardSale.price(cardID: cardID, perks: perks) * amount
        state.refundedTokens += refund
        state.cardsDisenchanted += amount
        save()
        AppLog.write("sold \(amount)x \(cardID) (\(tier.rawValue)) for \(refund)")
        return refund
    }

    // MARK: 한번에 판매

    /// 한번에 판매의 결과. 미리보기와 실제 판매가 같은 값을 쓴다 —
    /// 미리 본 것과 실제로 팔린 것이 다르면 되돌릴 수 없는 동작에서 신뢰가 무너진다.
    struct BulkSale: Equatable, Sendable {
        var kinds = 0        // 종류 수
        var copies = 0       // 장수
        var tokens = 0       // 받는 값

        static let none = BulkSale()
        var isEmpty: Bool { copies == 0 }
    }

    /// 값이 임계값 이하인 카드의 **중복분**을 고른다.
    ///
    /// 순수 함수로 분리해 검증할 수 있게 둔다. 「마지막 한 장은 남긴다」와 「임계값을 넘는
    /// 카드는 건드리지 않는다」가 이 기능의 전부이고, 눈으로만 확인하면 조용히 어긋난다.
    ///
    /// 임계값은 **카드 한 장 값**을 본다. 합계로 두면 많이 가진 카드가 비싼 카드가 된다.
    /// 시세를 모르는 카드는 `MarketEconomy.unknownUSD`(69원)로 잡혀 늘 대상에 든다 —
    /// 값을 모르는 카드는 잡카드로 보는 것이 맞다.
    static func bulkSaleTargets(_ entries: [CardEntry], maxWon: Int,
                                spares: (String) -> Int,
                                prices: CardPrices? = CardPrices.shared) -> [String] {
        entries.compactMap { entry in
            guard spares(entry.id) > 0 else { return nil }
            let usd = MarketEconomy.usd(cardID: entry.id, prices: prices)
            guard let prices, prices.krw(usd) <= maxWon else { return nil }
            return entry.id
        }
    }

    /// 팔면 무엇이 얼마인가. 상태를 바꾸지 않는다 — 화면이 매 프레임 부른다.
    func bulkSalePreview(_ targets: [String]) -> BulkSale {
        targets.reduce(into: BulkSale()) { sale, cardID in
            let spare = spareCount(cardID)
            guard spare > 0 else { return }
            sale.kinds += 1
            sale.copies += spare
            sale.tokens += CardSale.price(cardID: cardID, perks: perks) * spare
        }
    }

    /// 고른 카드의 중복분을 전부 판다.
    ///
    /// **저장은 한 번만 한다.** 종류마다 `sellSpares(cardID:tier:count:)` 를 부르면 164종
    /// 정리에 저장이 164번 돌고 도감 혜택도 164번 다시 계산된다.
    @discardableResult
    func sellSpares(_ targets: [String]) -> BulkSale {
        let sale = bulkSalePreview(targets)
        guard !sale.isEmpty else { return .none }

        for cardID in targets {
            let spare = spareCount(cardID)
            guard spare > 0 else { continue }
            state.cards[cardID] = cardCount(cardID) - spare
        }
        state.refundedTokens += sale.tokens
        state.cardsDisenchanted += sale.copies
        save()
        AppLog.write("bulk sold \(sale.copies)x from \(sale.kinds) kinds for \(sale.tokens)")
        return sale
    }

    // MARK: 한 번만 주는 보상

    /// 사과나 안내로 한 번만 주는 것. 값은 코드에 적고 지급 여부만 세이브에 남는다.
    struct Gift: Sendable, Equatable {
        /// 왜 주는가. 알림 문구가 이걸 보고 갈린다 — 사과와 기념은 다른 말이다.
        enum Kind: Sendable { case apology, celebration }

        /// 지급 기록에 남는 이름. 버전이 아니라 **보상마다** 다르게 붙인다.
        let id: String
        let tokens: Int
        /// 세트마다 몇 팩을 줄지.
        let packsPerSet: Int
        var kind: Kind = .apology
    }

    /// 받은 보상. 팝오버가 한 번 알리고 지운다.
    var lastGift: Gift?

    /// v0.4.1 사죄의 사료.
    ///
    /// v0.4.0 이 값을 반올림해 보여 준 탓에 적힌 값과 실제로 빠지는 값이 달랐다.
    /// 살 수 있다고 나오는 팩을 못 사고, 사고 나면 남은 돈이 계산과 맞지 않았다.
    static let apologyGift = Gift(id: "v0.4.1-apology", tokens: 213_370_000, packsPerSet: 1)

    /// v0.6.0 업데이트 기념 사료. 100만원.
    ///
    /// 토큰 수는 **정확히 100만원이 되는 값**이다 — 100원 한 칸이 21,337토큰이므로
    /// 만 칸이면 딱 떨어진다. 어정쩡한 액수가 뜨면 기념이 아니라 실수처럼 보인다.
    static let patchGift = Gift(id: "v0.6.0-patch", tokens: 213_370_000, packsPerSet: 0,
                                kind: .celebration)

    /// v0.7.0 업데이트 기념 사료. 100만원.
    ///
    /// 토큰 수가 `patchGift` 와 같은 이유는 둘 다 **정확히 100만원**이기 때문이다 —
    /// 100원 한 칸이 21,337토큰이므로 만 칸이면 딱 떨어진다. `id` 는 반드시 달라야 한다.
    /// 같으면 v0.6.0 에서 이미 받은 사람이 이번 것을 못 받는다.
    static let oripaUpdateGift = Gift(id: "v0.7.0-patch", tokens: 213_370_000, packsPerSet: 0,
                                      kind: .celebration)

    /// v0.8.0 업데이트 기념 사료. 100만원.
    ///
    /// 앞의 두 기념과 값이 같은 이유는 셋 다 **정확히 100만원**이기 때문이다 —
    /// 100원 한 칸이 21,337토큰이므로 만 칸이면 딱 떨어진다. `id` 는 반드시 달라야 한다.
    /// 같으면 앞 버전에서 이미 받은 사람이 이번 것을 못 받는다.
    static let dexUpdateGift = Gift(id: "v0.8.0-patch", tokens: 213_370_000, packsPerSet: 0,
                                    kind: .celebration)

    /// 준 적이 없고 대상이면 준다. 이미 줬으면 아무것도 하지 않는다.
    ///
    /// **이미 팩을 사 본 세이브만** 받는다. 갓 설치한 사람이 백만원을 들고 시작하면
    /// 초반에 무엇을 살지 고르는 재미가 통째로 사라진다.
    ///
    /// 대상이 아니어도 기록은 남긴다 — 안 남기면 나중에 팩을 하나 사는 순간 대상이 되어
    /// 뒤늦게 지급된다.
    @discardableResult
    func claim(_ gift: Gift, index: CardIndex? = CardIndex.shared) -> Bool {
        guard !state.grantedGifts.contains(gift.id) else { return false }
        state.grantedGifts.append(gift.id)

        let affected = state.packsOpened > 0 || state.spentTokens > 0
        guard affected else {
            save()
            AppLog.write("gift \(gift.id) skipped — 대상 아님")
            return false
        }

        state.perkTokens += gift.tokens
        if let index, gift.packsPerSet > 0 {
            for setID in index.setIDs { state.packs[setID, default: 0] += gift.packsPerSet }
        }
        save()
        lastGift = gift
        AppLog.write("gift \(gift.id) granted tokens=\(gift.tokens) packs=\(gift.packsPerSet)/set")
        return true
    }

    /// 안내를 봤다. 다시 띄우지 않는다.
    func consumeGift() { lastGift = nil }

    // MARK: 최애 카드 (메뉴바)

    var favoriteCardID: String? { state.favoriteCardID }

    /// 최애 카드를 지정한다. 갖고 있지 않은 카드는 받지 않는다 —
    /// 메뉴바에 못 그리는 카드를 가리킨 채로 두면 아이콘이 조용히 사라진다.
    func setFavorite(_ cardID: String?) {
        if let cardID, cardCount(cardID) == 0 { return }
        guard state.favoriteCardID != cardID else { return }
        state.favoriteCardID = cardID
        save()
        AppLog.write("favorite card = \(cardID ?? "none")")
    }

    /// 메뉴바에 올릴 카드. 최애 → 최고 등급 → 없음.
    func menuBarCard(index: CardIndex?) -> CardEntry? {
        MenuBarCard.resolve(favorite: state.favoriteCardID, owned: state.cards, index: index)
    }

    // MARK: 카드 보유량

    func cardCount(_ cardID: String) -> Int { state.cards[cardID] ?? 0 }

    /// 이 카드를 처음 얻은 때. 기록이 생기기 전에 모은 카드는 nil 이다.
    func firstAcquired(_ cardID: String) -> Date? {
        state.cardFirstAt[cardID].map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// 정렬에 쓸 값. 기록이 없으면 0 — 획득 순에서 맨 뒤로 간다.
    func firstAcquiredStamp(_ cardID: String) -> Int { state.cardFirstAt[cardID] ?? 0 }

    var distinctCardCount: Int { state.cards.count }

    var totalCardCount: Int { state.cards.values.reduce(0, +) }

    /// 모은 카드를 지금 시세로 매긴 총액(달러). 중복도 장수만큼 센다.
    ///
    /// "몇 장 모았나" 만으로는 컬렉션이 자라는 감각이 약하다. 1999년 커먼 한 장이 최신
    /// SR 보다 비싸기도 해서, 장수와 값이 서로 다른 이야기를 한다.
    func collectionValueUSD(prices: CardPrices? = CardPrices.shared) -> Double {
        let owned = state.cards.reduce(0.0) { running, entry in
            running + MarketEconomy.usd(cardID: entry.key, prices: prices) * Double(entry.value)
        }
        let held = unrevealed.reduce(0.0) { running, entry in
            running + MarketEconomy.usd(cardID: entry.key, prices: prices) * Double(entry.value)
        }
        return max(0, owned - held)
    }

    // MARK: 개봉 연출 중 값 감추기

    /// 아직 뒤집어 보지 않은 카드. 컬렉션 가치 **표시에서만** 뺀다.
    ///
    /// 카드는 뽑는 순간 수집함에 들어간다 — 연출이 끝날 때까지 미루면 도중에 팝오버를 닫는
    /// 순간 뽑은 카드가 사라진다. 그런데 머리글의 컬렉션 가치는 늘 보이므로, 값이 먼저
    /// 올라가면 무엇이 나왔는지 카드를 뒤집기 전에 알게 된다. 그래서 값만 늦춘다.
    ///
    /// 저장하지 않는다. 앱을 다시 켜면 이미 다 본 것으로 친다 — 연출은 그 자리에서 끝난다.
    private(set) var unrevealed: [String: Int] = [:]

    /// 이 카드들을 아직 안 본 것으로 둔다.
    func holdForReveal(_ cardIDs: [String]) {
        var held: [String: Int] = [:]
        for id in cardIDs { held[id, default: 0] += 1 }
        unrevealed = held
    }

    /// 한 장을 봤다.
    func markRevealed(_ cardID: String) {
        guard let count = unrevealed[cardID] else { return }
        if count <= 1 { unrevealed.removeValue(forKey: cardID) } else { unrevealed[cardID] = count - 1 }
    }

    /// 남은 전부를 봤다 — 요약 화면은 카드를 한꺼번에 보여 준다.
    func markAllRevealed() {
        guard !unrevealed.isEmpty else { return }
        unrevealed = [:]
    }

    /// 개봉 결과를 수집함에 넣는다. 같은 카드가 여러 장 나오면 그만큼 쌓인다.
    ///
    /// 새로 완성된 도감을 함께 처리하고 그 목록을 돌려준다. 카드가 들어오는 경로가
    /// 여기뿐이라 판정을 여기 두면 호출부가 잊을 수 없다 — 화면마다 판정을 심으면
    /// 언젠가 한 곳이 빠지고, 그 화면으로 얻은 카드는 도감을 완성시키지 못한다.
    @discardableResult
    func collect(_ cardIDs: [String]) -> [DexCompletion] {
        guard !cardIDs.isEmpty else { return [] }
        let before = Set(state.cards.keys)
        let now = Int(Date().timeIntervalSince1970)
        for id in cardIDs {
            state.cards[id, default: 0] += 1
            // 처음 얻은 때만 적는다. 두 번째부터 덮어쓰면 「최초」가 아니게 된다.
            if state.cardFirstAt[id] == nil { state.cardFirstAt[id] = now }
        }
        save()

        return DexProgress.newlyFilled(dexes: dexes, owned: { (state.cards[$0] ?? 0) > 0 },
                                       claimed: claimedDexIDs, before: before)
            .map { DexCompletion(dexID: $0.id, name: $0.name, tier: $0.tier) }
    }

    /// 세트의 천장 카운터. 개봉이 이 값을 읽고, 개봉 후 `setPity` 로 되돌려 준다.
    func pity(setID: String) -> Int { state.packPity[setID] ?? 0 }

    func setPity(_ value: Int, setID: String) {
        if value == 0 { state.packPity.removeValue(forKey: setID) } else { state.packPity[setID] = value }
        save()
    }

    // MARK: 오리파

    /// 지금 걸려 있는 박스. 없으면 새로 채운다.
    ///
    /// 화면을 그릴 때마다 호출되므로 이미 있으면 그대로 돌려준다. 박스를 새로 채우는 것은
    /// 처음 열 때와 다 팔렸을 때뿐이다.
    func oripaBox(index: CardIndex) -> OripaBox {
        // 봉투 수가 맞지 않는 박스는 버린다. 구성표를 바꾼 배포에서 넘어온 옛 박스라
        // 그대로 두면 격자가 넘치거나 값이 구성표와 어긋난다.
        if let box = state.oripa, !box.isEmpty, box.cards.count == OripaConfig.slotsPerBox {
            return box
        }
        state.oripa = freshOripaBox(index: index)
        save()
        return state.oripa!
    }

    /// 미보유 카드를 앞세워 박스를 채운다. 최소 보상을 올리는 것이 목적이다.
    private func freshOripaBox(index: CardIndex) -> OripaBox {
        var generator = SystemRandomNumberGenerator()
        return Oripa.makeBox(index: index, serial: (state.oripa?.serial ?? 0) + 1,
                             owns: { self.cardCount($0) > 0 },
                             using: &generator)
    }

    /// 박스를 버리고 새로 받는다. 값은 받지 않는다.
    ///
    /// 마음에 안 드는 박스를 비우려면 40봉투를 다 사야 한다면, 그건 850만원을 태워야 진열이
    /// 바뀐다는 뜻이라 기능이 아니라 함정이다. 실제 오리파 사이트도 박스를 여러 개 늘어놓고
    /// 고르게 한다.
    ///
    /// 무료로 둬도 기댓값이 오르지 않는다 — 값이 남은 봉투를 따라가므로 어느 박스에서든
    /// 회수율이 `1/margin` 으로 같다. 교체로 얻는 것은 "원하는 카드가 든 박스를 고를 수
    /// 있다" 는 것뿐이고, 그 카드를 실제로 뽑으려면 여전히 40봉투를 헤쳐야 한다.
    ///
    /// 값이 남은 것을 따라가므로 **올라가는 경우도 생긴다** — 싼 봉투만 빠지면 남은 평균이
    /// 오른다. 그때 버릴 수 있어야 실제 값이 새 박스 값을 넘지 않는다.
    func replaceOripaBox(index: CardIndex) {
        let box = freshOripaBox(index: index)
        state.oripa = box
        save()
        AppLog.write("oripa box replaced serial=\(box.serial)")
    }

    /// 지금 박스에서 봉투 하나를 여는 값. **남은 봉투에 따라 바뀐다.**
    ///
    /// 팩 할인 혜택이 여기에도 걸린다 — 같은 상점에서 사는 물건이다.
    func oripaPrice(index: CardIndex? = CardIndex.shared) -> Int {
        guard let index else { return 30_000_000 }
        let base = OripaConfig.slotPrice(box: oripaBox(index: index))
        guard perks.packDiscount > 0 else { return base }
        // 할인을 곱하면 100원 칸에서 벗어난다. 곱한 뒤에 다시 끊는다.
        return MarketEconomy.quantized(Int((Double(base) * (1 - perks.packDiscount)).rounded()))
    }

    /// 고른 봉투를 연다. 잔액이 모자라거나 이미 연 봉투면 아무것도 하지 않고 nil.
    ///
    /// 차감을 먼저 한다. 뽑기가 먼저면 실패했을 때 카드만 나가고 값을 못 받는다.
    @discardableResult
    func pullOripa(index: CardIndex, envelope: Int)
        -> (card: PulledCard, completions: [DexCompletion])? {
        var box = oripaBox(index: index)
        guard box.cards.indices.contains(envelope), !box.opened.contains(envelope),
              spend(oripaPrice(index: index)) else { return nil }

        guard let id = Oripa.open(envelope, in: &box) else { return nil }
        let isNew = cardCount(id) == 0
        state.oripa = box
        let completions = collect([id])   // 저장까지 여기서 한다
        // 가림막을 걷기 전까지는 값을 올리지 않는다 — 오리파도 뒤집어 보는 연출이다.
        holdForReveal([id])
        AppLog.write("oripa opened \(envelope) -> \(id) box=\(box.serial) remaining=\(box.remaining)")
        return (PulledCard(id: id, tier: index.card(id)?.tier ?? .doubleRare, isNew: isNew),
                completions)
    }

    // MARK: 조합 도감

    /// 보상까지 받은 도감. 혜택은 이 목록에서만 나온다.
    var claimedDexIDs: Set<String> { Set(state.claimedDex) }

    var claimedDexCount: Int { state.claimedDex.count }

    /// 완성으로 세어지는 도감 수. **계단이 이 값을 센다.**
    var completedDexCount: Int {
        let claimed = claimedDexIDs
        return dexes.filter { claimed.contains($0.completionKey) }.count
    }

    /// 열린 계단 칸.
    var reachedLadder: [DexLadderStep] {
        let done = completedDexCount
        return ladder.filter { done >= $0.completed }
    }

    /// 얻은 칭호 — 열린 계단 칸이 그대로 칭호다.
    var titles: [DexLadderStep] { reachedLadder }

    /// 고른 칭호. 아직 안 골랐으면 가장 높은 것을 쓴다 — 얻었는데 안 보이면 보상이 아니다.
    var title: DexText? {
        let got = titles
        guard !got.isEmpty else { return nil }
        if let picked = state.title, let step = got.first(where: { $0.completed == picked }) {
            return step.title
        }
        return got.last?.title
    }

    /// 고른 칭호의 계단 번호. 안 골랐으면 nil — 화면의 선택기가 이 값을 쓴다.
    var stateTitleChoice: Int? { state.title }

    func setTitle(_ completed: Int?) { state.title = completed; save() }

    /// 갖고 있는 쿠폰 — 남은 장수가 있는 것만, **세트와 할인율이 같으면 한 줄로 묶는다.**
    ///
    /// 도감 칸마다 따로 들어오므로 저장에는 여러 묶음이 남는다. 쿠폰함이 그것을 그대로
    /// 늘어놓으면 「Base 50% 1장」이 두 줄로 보여서 몇 장인지 세게 된다.
    var activeCoupons: [PackCoupon] {
        var merged: [PackCoupon] = []
        for coupon in state.coupons where coupon.left > 0 {
            if let i = merged.firstIndex(where: { $0.setID == coupon.setID
                                                  && $0.value == coupon.value }) {
                merged[i].left += coupon.left
            } else {
                merged.append(coupon)
            }
        }
        return merged
    }

    /// 그 세트에 쓸 수 있는 쿠폰 장수.
    func couponCount(setID: String) -> Int {
        state.coupons.filter { $0.setID == setID }.reduce(0) { $0 + max(0, $1.left) }
    }

    /// 그 세트 쿠폰의 할인율. 여러 장이면 가장 센 것을 쓴다.
    func couponDiscount(setID: String) -> Double {
        state.coupons.filter { $0.setID == setID && $0.left > 0 }
            .map(\.value).max() ?? 0
    }

    /// 정가 — 영구 할인만 반영한다. 상점이 줄을 그어 보여 줄 값이다.
    func listPrice(setID: String, index: CardIndex) -> Int {
        PackPricing.price(setID: setID, index: index, perks: perks)
    }

    /// **실제로 낼 값.** 쿠폰이 있으면 그만큼 더 깎인다.
    ///
    /// 쿠폰은 한 번에 한 장씩 쓰이므로, 여러 개를 살 때는 쿠폰이 있는 만큼만 할인된다.
    /// 그래서 총액은 낱개 값의 곱이 아니라 이 함수로 세어야 한다.
    func packTotal(setID: String, count: Int, index: CardIndex) -> Int {
        let list = listPrice(setID: setID, index: index)
        let discounted = couponCount(setID: setID)
        guard discounted > 0 else { return list * count }
        let rate = couponDiscount(setID: setID)
        let cut = MarketEconomy.quantized(Int((Double(list) * (1 - rate)).rounded()))
        let withCoupon = min(count, discounted)
        return cut * withCoupon + list * (count - withCoupon)
    }

    /// 낱개 값 — 쿠폰이 있으면 쿠폰가다. 상점이 큰 글씨로 적는 값이다.
    func packPrice(setID: String, index: CardIndex) -> Int {
        let list = listPrice(setID: setID, index: index)
        let rate = couponDiscount(setID: setID)
        guard rate > 0 else { return list }
        return MarketEconomy.quantized(Int((Double(list) * (1 - rate)).rounded()))
    }

    /// 도감 진행. 세트 도감은 그 세트의 종 목록이 필요하다.
    func dexStatus(_ dex: Dex, index: CardIndex? = CardIndex.shared) -> DexStatus {
        DexProgress.status(for: dex, owned: { (state.cards[$0] ?? 0) > 0 },
                           claimed: claimedDexIDs,
                           setCards: { index?.cards(inSet: $0) ?? [] })
    }

    /// 지금 보유 카드로 받을 것이 있는 도감.
    ///
    /// 완성 여부를 저장하지 않고 매번 보유 카드에서 계산한다 — 도감 기능이 생기기 전에
    /// 모아 둔 카드도 그래야 완성으로 잡힌다. 이벤트로만 기록하면 그런 도감은 영영 안 뜬다.
    var claimableDexes: [Dex] {
        dexes.filter { dexStatus($0).isClaimable }
    }

    /// 보상을 수령한다.
    ///
    /// 두 번 주면 도감으로 재화를 무한히 만들 수 있으므로 이미 수령한 칸은 거른다.
    /// 도달하지 못한 칸도 거른다 — 화면이 잘못 눌러도 지급되지 않아야 한다.
    @discardableResult
    func claim(_ dexID: String, step: Int = 0,
               index: CardIndex? = CardIndex.shared) -> DexClaim? {
        guard let dex = dexes.first(where: { $0.id == dexID }) else { return nil }
        let status = dexStatus(dex, index: index)
        guard status.steps.contains(step), status.isReached(step), !status.isClaimed(step)
        else { return nil }

        let reward = status.reward(step)
        state.claimedDex.append(dex.claimKey(step))

        if reward.packs > 0 { state.packs[dex.homeSet, default: 0] += reward.packs }
        if reward.tokens > 0 { state.perkTokens += reward.tokens }
        // 쿠폰은 **그 도감의 세트**에 묶인다. 어느 세트에나 쓸 수 있으면 가장 비싼 팩을
        // 노리고 돈을 모으는 것이 최적이 되어, 보상이 소비를 막는다.
        for coupon in reward.coupons where coupon.count > 0 {
            // 같은 세트·같은 할인율은 한 묶음에 더한다. 따로 쌓으면 저장이 늘어나기만 한다.
            if let i = state.coupons.firstIndex(where: { $0.setID == dex.homeSet
                                                         && $0.value == coupon.value }) {
                state.coupons[i].left += coupon.count
            } else {
                state.coupons.append(PackCoupon(setID: dex.homeSet, value: coupon.value,
                                                left: coupon.count))
            }
        }
        var granted: String?
        if let want = reward.card, let index {
            granted = grantCard(want, index: index)
        }
        // 혜택은 즉시 반영한다 — 수령 직후의 구매·개봉부터 적용되어야 보상으로 읽힌다.
        refreshPerks()
        save()
        AppLog.write("dex claimed \(dex.claimKey(step)) packs=\(reward.packs)"
                     + " tokens=\(reward.tokens) coupons=\(reward.coupons.count)"
                     + " card=\(granted ?? "-")")
        return DexClaim(dex: dex, step: step, reward: reward, card: granted)
    }

    /// 확정 카드를 한 장 준다.
    ///
    /// **등급이 아니라 값으로 고른다.** 「UR 이상 랜덤」의 중앙값이 17,400원인데 평균은
    /// 160,600원이다 — 분포가 아래로 쏠려 있어 등급만 정하면 대개 1~2만원짜리가 나온다.
    /// 오리파에서 겪은 것과 같은 문제고, 답도 같다.
    ///
    /// **미보유부터 고른다.** 중복 한 장은 「팔 물건」이고, 완성 보상이 팔 물건이면 축하가
    /// 아니라 정산이 된다. 값이 맞는 미보유가 없으면 가진 카드로 메운다.
    private func grantCard(_ want: DexCardGrant, index: CardIndex) -> String? {
        let floor = CardTier(rawValue: want.tierFloor)
        let pool = index.cards.filter { entry in
            guard let floor else { return true }
            return entry.tier.rank >= floor.rank
        }
        guard !pool.isEmpty else { return nil }
        let distance = { (id: String) in
            abs(MarketEconomy.usd(cardID: id, prices: CardPrices.shared) - want.targetUSD)
        }
        let fresh = pool.filter { (state.cards[$0.id] ?? 0) == 0 }
        let picked = (fresh.isEmpty ? pool : fresh).min { distance($0.id) < distance($1.id) }
        guard let picked else { return nil }
        // 「처음 얻은 때」는 `collect` 가 적는다. 확정 카드도 같은 길을 지나야
        // 컬렉션의 최근 획득순 정렬에 들어간다.
        _ = collect([picked.id])
        return picked.id
    }

    /// 그 세트 쿠폰 한 장을 쓴다. 다 쓴 묶음은 목록에서 지운다.
    ///
    /// 할인이 가장 센 것부터 쓴다 — 여러 장이 있으면 사용자가 이득인 쪽으로 소모돼야 한다.
    private func consumeCoupons(setID: String, times: Int) {
        guard times > 0 else { return }
        var remaining = times
        let order = state.coupons.indices
            .filter { state.coupons[$0].setID == setID && state.coupons[$0].left > 0 }
            .sorted { state.coupons[$0].value > state.coupons[$1].value }
        for i in order {
            guard remaining > 0 else { break }
            let take = min(remaining, state.coupons[i].left)
            state.coupons[i].left -= take
            remaining -= take
        }
        state.coupons.removeAll { $0.left <= 0 }
    }

    /// 팩을 산다. **값을 깎고, 보유량을 늘리고, 쿠폰을 그만큼 쓴다.**
    ///
    /// 세 가지를 따로 부르면 한 군데를 잊는다 — 실제로 쿠폰을 안 깎아 영구 할인이 됐다.
    @discardableResult
    func buyPacks(setID: String, count: Int, total: Int) -> Bool {
        guard count > 0, spend(total) else { return false }
        state.packs[setID, default: 0] += count
        consumeCoupons(setID: setID, times: count)
        save()
        return true
    }

    // MARK: 보너스 팩 (한도 달성 보상)

    /// 창 하나에 기억해 두는 판의 최대 개수. 판은 초기화 시각이 지나면 다시 나타나지 않으므로
    /// 오래된 것부터 버려도 두 번 지급되지 않는다. 계정 몇 개를 오가도 남을 만큼은 둔다.
    static let grantMemory = 24

    /// 지급 판정 — 한도 창이 **아직 지급하지 않은 판**에서 100% 에 닿았을 때만 지급한다.
    ///
    /// - 판을 아는 창: 그 판에 이미 준 적이 있으면 건너뛴다. 100% 아래로 내려가도 기록을
    ///   지우지 않는다 — 계정을 바꿔 0% 가 된 것을 「초기화됐다」로 읽으면 안 된다.
    /// - 판을 모르는 창: 예전 규칙 그대로 100% 미만이면 다시 무장한다.
    /// - 세트는 주어진 목록에서 무작위로 하나 고른다. 난수 생성기를 주입받아 검증 가능하게 둔다.
    ///
    /// 부수효과(보유량 증가·알림)와 분리했다.
    static func evaluateGrants(
        windows: [BonusWindow],
        grantTier: inout [String: Int],
        grantedInstances: inout [String: [String]],
        availableSets: [BonusSet],
        using generator: inout some RandomNumberGenerator
    ) -> [PackGrant] {
        guard !availableSets.isEmpty else { return [] }
        var grants: [PackGrant] = []
        for w in windows {
            guard w.utilization >= 100 else {
                if w.instance.isEmpty { grantTier[w.key] = nil }
                continue
            }
            if w.instance.isEmpty {
                guard (grantTier[w.key] ?? 0) < 1 else { continue }
            } else {
                var paid = grantedInstances[w.key] ?? []
                guard !paid.contains(w.instance) else { continue }
                paid.append(w.instance)
                if paid.count > grantMemory { paid.removeFirst(paid.count - grantMemory) }
                grantedInstances[w.key] = paid
            }
            // 판을 알든 모르든 옛 표시도 같이 남긴다. 초기화 시각이 응답에서 잠깐 빠지면 같은 창이
            // 판 없는 창으로 보이는데, 그때 이 표시가 없으면 이미 준 창을 한 번 더 준다.
            grantTier[w.key] = 1
            // 한도 종류와 무관하게 같은 값이다. 세션 한도가 주간보다 자주 차므로,
            // 주간에 가중을 주면 보상이 세션 쪽으로 쏠린다.
            let payout = bonusPayout(from: availableSets, using: &generator)
            grants.append(PackGrant(windowKey: w.key, windowName: w.name,
                                    setID: payout.setID, count: payout.count))
        }
        return grants
    }

    /// 보너스 한 번의 지급 내용 — **예산에 맞춰** 세트와 개수를 고른다.
    ///
    /// 예산으로 한 팩도 못 사는 세트는 후보에서 뺀다. 남겨 두면 그 세트가 걸리는 순간
    /// 예산의 몇십 배가 한 번에 나가고, 그게 「랜덤이라 값이 튄다」는 문제 그 자체다.
    /// 살 수 있는 세트가 하나도 없으면(예산보다 다 비싸면) 제일 싼 세트로 한 팩을 준다 —
    /// 보상이 아예 안 나오는 것보다는 낫다.
    static func bonusPayout(
        from sets: [BonusSet],
        using generator: inout some RandomNumberGenerator
    ) -> (setID: String, count: Int) {
        let budget = PackConfig.bonusBudget
        let affordable = sets.filter { $0.price > 0 && $0.price <= budget }
        if affordable.isEmpty {
            let cheapest = sets.min { $0.price < $1.price } ?? sets[0]
            return (cheapest.id, 1)
        }
        let pick = affordable[Int(generator.next(upperBound: UInt64(affordable.count)))]
        return (pick.id, min(PackConfig.bonusPackCap, max(1, budget / pick.price)))
    }

    /// 판 기록이 생기기 전의 세이브를 이어 받는다.
    ///
    /// 옛 세이브에는 「지급했다」는 사실만 있고 어느 판이었는지가 없다. 그대로 두면 업데이트
    /// 직후 지금 차 있는 창이 미지급으로 보여 한 번 더 지급된다. 지금 관측된 판을 그 자리에
    /// 적어 두면 새 규칙이 옛 기록을 그대로 물려받는다.
    private func adoptLegacyGrantMarks(_ windows: [BonusWindow]) {
        for w in windows where !w.instance.isEmpty {
            guard state.packGrantedInstances[w.key] == nil else { continue }
            guard (state.packGrantTier[w.key] ?? 0) >= 1, w.utilization >= 100 else { continue }
            state.packGrantedInstances[w.key] = [w.instance]
        }
    }

    /// 한도 창 상태로부터 보너스 팩을 지급한다. 매 새로고침 완료 시(한도 로드 후) 호출한다.
    ///
    /// - 첫 실행에는 지급 없이 현재 100% 인 창만 시드한다. 설치 직후 이미 차 있던 창에
    ///   소급 지급하지 않기 위한 것이다.
    /// - 한도가 아직 로드되지 않았으면 시드도 지급도 하지 않고 다음 새로고침에 재시도한다.
    @discardableResult
    func grantBonusPacks(from windows: [BonusWindow], limitsReady: Bool,
                         availableSets: [BonusSet]) -> [PackGrant] {
        guard limitsReady, !availableSets.isEmpty else { return [] }

        if !state.packGrantSeeded {
            for w in windows where w.utilization >= 100 {
                if w.instance.isEmpty { state.packGrantTier[w.key] = 1 }
                else { state.packGrantedInstances[w.key] = [w.instance] }
            }
            state.packGrantSeeded = true
            save()
            return []
        }

        adoptLegacyGrantMarks(windows)

        let before = state.packGrantTier
        let beforeInstances = state.packGrantedInstances
        var generator = SystemRandomNumberGenerator()
        // `state` 가 계산 프로퍼티라 두 칸을 동시에 inout 으로 넘길 수 없다. 지역 변수로 꺼냈다 넣는다.
        var tier = state.packGrantTier
        var instances = state.packGrantedInstances
        let grants = Self.evaluateGrants(windows: windows, grantTier: &tier,
                                         grantedInstances: &instances,
                                         availableSets: availableSets, using: &generator)
        state.packGrantTier = tier
        state.packGrantedInstances = instances
        for g in grants {
            state.packs[g.setID, default: 0] += g.count
            lastGrant = g
            AppLog.write("bonus packs granted window=\(g.windowKey) set=\(g.setID) count=\(g.count)")
        }

        // 지급이 없어도 재무장(창이 100% 아래로 내려가 맵에서 제거된 것)과 판 기록은 영속해야
        // 한다. 안 하면 재시작 시 남은 표시 때문에 다음 도달을 "이미 지급" 으로 오판하거나,
        // 반대로 이미 준 판을 다시 준다.
        if !grants.isEmpty || state.packGrantTier != before
            || state.packGrantedInstances != beforeInstances { save() }
        return grants
    }

    // MARK: 영속

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }   // 파일 없음 = 신규 설치
        guard let decoded = try? JSONDecoder().decode(GameState.self, from: data) else {
            // 디코드 실패(전면 손상) → 새로 시작하되, 다음 저장이 원본을 덮어써 영구 유실되기 전에
            // 보존해 수동 복구 여지를 남긴다.
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            AppLog.write("game state decode failed — original backed up to \(backup.lastPathComponent), starting fresh")
            return
        }
        state = decoded
        backfillFirstAcquired()
    }

    /// 획득 날짜 기록이 생기기 전에 모은 카드에 **오늘 날짜를 채운다.**
    ///
    /// 기록이 없으면 카드 상세에 날짜가 안 뜨고 「최근 획득순」에서 맨 뒤로 밀린다. 이미
    /// 수백 장을 모은 세이브에서는 그게 대부분의 카드라, 두 기능이 사실상 빈 채로 남는다.
    /// 실제로 언제 얻었는지는 어디에도 없으므로 지어낼 수 없고, 대신 **처음 본 날**을
    /// 적는다 — 「적어도 이날에는 갖고 있었다」는 사실이다.
    ///
    /// 한 번만 채워진다. 채운 뒤에는 빈 카드가 없고, 새로 얻는 카드는 그때 시각이 박힌다.
    /// 그래서 채워 넣은 카드가 앞으로 얻을 카드보다 항상 앞선다.
    private func backfillFirstAcquired() {
        let missing = state.cards.filter { $0.value > 0 && state.cardFirstAt[$0.key] == nil }
        guard !missing.isEmpty else { return }
        let now = Int(Date().timeIntervalSince1970)
        for id in missing.keys { state.cardFirstAt[id] = now }
        save()
        AppLog.write("card first-seen backfilled for \(missing.count) cards")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)   // 부분 쓰기 손상 방지
    }
}
