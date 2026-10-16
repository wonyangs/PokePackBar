import CryptoKit
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
struct DexClaim: Codable, Sendable, Equatable {
    let dex: Dex
    let step: Int
    let reward: DexReward
    /// 확정 카드로 받은 카드. 없으면 nil.
    let card: String?
}

/// 이번 개봉으로 다 모인 도감 1건. 개봉 결과 화면이 이걸 받아 알린다.
/// 보상은 여기서 주지 않는다 — 수령은 도감 화면에서 사용자가 직접 누른다.
struct DexCompletion: Codable, Equatable, Sendable, Identifiable {
    let dexID: String
    let name: DexText
    let tier: Int

    var id: String { dexID }
}

/// 여러 팩을 한 번에 연 결과. 저장은 한 번만 하지만 확률·천장·개봉 이력은 팩별로 계산한다.
struct OpenedPackBatch: Codable, Sendable {
    let packs: [OpenedCards]
    let completions: [DexCompletion]

    var cards: [PulledCard] { packs.flatMap(\.cards) }
}

extension CardSale {
    /// 특정 인쇄본 한 장의 판매가. 정확한 판형 시세가 없으면 카드 대표 시세로 폴백한다.
    static func price(cardID: String, finish: CardFinish,
                      prices: CardPrices? = CardPrices.shared,
                      perks: DexPerks = .none) -> Int {
        let usd = MarketEconomy.usd(cardID: cardID, finish: finish, prices: prices)
        return sale(market: MarketEconomy.tokens(usd: usd, prices: prices), prices: prices, perks: perks)
    }
}

/// 재화(토큰) 지갑과 카드·팩 보유량을 관리한다.
///
/// 사용량 적립 로직은 기존 컴패니언 저장소의 것을 그대로 옮겼다. 프로바이더별 장부,
/// 날짜 전환, 역행 시 개별 rebase 는 실제 결함을 고쳐 온 산물이라 재설계하지 않는다.
/// 컴패니언 관련 분기(알 인큐베이션·진화 진행)만 걷어냈다.
@MainActor
@Observable
final class WalletStore {

    private(set) var state = GameState() { didSet { collectionValueCache = nil; printingLedgerCache = nil } }
    /// 머리글의 컬렉션 가치. 계산에 10ms 안팎이 들어 팝오버를 그릴 때마다 다시 하지 않고,
    /// 상태나 시세가 바뀐 뒤 처음 읽을 때만 계산한다.
    @ObservationIgnored private var collectionValueCache: (prices: Int, value: Double)?
    /// 카드별로 묶은 판형 장부.
    ///
    /// `printingCards` 는 「카드#판형」 한 줄씩이라 카드 하나의 판형을 알려면 전체를 훑어야 한다.
    /// 카드마다 그렇게 하면 한번에 판매처럼 수백 종을 보는 화면이 그릴 때마다 멈췄다. 판형 2,547줄에
    /// 중복 576종인 실제 세이브에서 한 번 그리는 데 0.25초, 마켓이나 교환에 묶인 카드가 하나라도
    /// 있으면 전체 카드 18,949종을 훑어 8초가 걸렸다. 상태가 바뀐 뒤 처음 읽을 때 한 번만 묶는다.
    private struct PrintingLedger {
        /// 카드의 판형별 장수. 0장 이하인 줄은 뺀다.
        var counts: [String: [CardFinish: Int]] = [:]
        /// 카드에 딸린 저장 키 전부(0장인 줄 포함). 그 카드의 줄만 골라 지울 때 쓴다.
        var keys: [String: [String]] = [:]
    }
    @ObservationIgnored private var printingLedgerCache: PrintingLedger?
    private let fileURL: URL
    @ObservationIgnored private var durableState = GameState()
    @ObservationIgnored private var transactionDepth = 0
    @ObservationIgnored private var savingBlocked = false
    @ObservationIgnored private var commitState: ((GameState) throws -> Void)?
    private(set) var persistenceError: String?
    private(set) var recoveredSave = false
    private(set) var isOpeningPacks = false
    /// Server supplied reservation floors, never trusted from game commands.
    var protectedPrintings: [String: Int] = [:]
    private(set) var remote: RemoteGameSession?
    var isOnline: Bool { remote != nil }
    var saveBackupDirectory: URL { GamePersistence(url: fileURL).backupDirectory }

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

    init(fileURL: URL? = nil, dexes: [Dex]? = nil, ladder: [DexLadderStep]? = nil,
         commitState: ((GameState) throws -> Void)? = nil) {
        let localURL = fileURL ?? Self.defaultURL()
        let config = fileURL == nil ? RemoteGameConfiguration.load() : nil
        let session = config.map { RemoteGameSession(configuration: $0, localRoot: localURL.deletingLastPathComponent()) }
        let invalidConnection = fileURL == nil && RemoteGameConfiguration.requested && config == nil
        self.fileURL = session?.cacheURL ?? (invalidConnection
            ? localURL.deletingLastPathComponent().appendingPathComponent("invalid-online-config.json") : localURL)
        self.remote = session
        self.commitState = commitState
        let bundled = (dexes == nil || ladder == nil) ? DexIndex.loadBundled() : nil
        self.dexes = dexes ?? bundled?.dexes ?? []
        self.ladder = ladder ?? bundled?.ladder ?? []
        if invalidConnection {
            savingBlocked = true
            persistenceError = L(AppLanguage.current).invalidOnlineConfig
        } else { load() }
        refreshPerks()
        if fileURL == nil { AppLanguage.current = language }
        session?.onSnapshot = { [weak self] state in
            guard let self else { return }
            self.state = state
            AppLanguage.current = self.language
            self.protectedPrintings = self.remote?.reservedPrintings.mapValues { $0 + 1 } ?? [:]
            self.durableState = state
            self.refreshPerks()
            self.persistenceError = nil
            self.savingBlocked = false
        }
        session?.start()
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
            dir = AppEnv.supportDirectory
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("game-state.json")
    }

    var l: L { L(language) }
    var language: AppLanguage {
        if isOnline, let value = UserDefaults.standard.string(forKey: "ppb.online.language"),
           let language = AppLanguage(rawValue: value) { return language }
        return state.language
    }
    var openingPerks: DexPerks { state.openingMode == .realistic ? .none : perks }
    func setOpeningMode(_ mode: OpeningMode) {
        if isOnline { updateRemotePreferences(mode: mode); return }
        state.openingMode = mode; save()
    }
    func setLanguage(_ lang: AppLanguage) {
        AppLanguage.current = lang
        if isOnline {
            UserDefaults.standard.set(lang.rawValue, forKey: "ppb.online.language")
            state.language = lang; durableState.language = lang
            return
        }
        state.language = lang; save()
    }

    // MARK: 재화

    /// 상점에서 쓸 수 있는 토큰 = 누적 사용량 − 지출 + 갈아 돌려받은 것 + 도감 혜택 적립분.
    var availableTokens: Int {
        max(0, state.usedSinceInstall - state.spentTokens + state.refundedTokens + state.perkTokens
            + state.marketEarnedTokens - state.marketSpentTokens)
    }

    var usedSinceInstall: Int { state.usedSinceInstall }

    /// 설치 기준선이 아직 안 잡혔는가 — 사용량 데이터가 한 번도 도착하지 않은 상태.
    /// UI 가 "아직 0" 과 "측정 시작 전" 을 구분해 안내할 수 있게 노출한다.
    var awaitingFirstUsage: Bool { remote?.awaitingFirstUsage ?? !state.installBaselineSet }

    /// 재화를 차감한다. 잔액이 부족하면 아무것도 하지 않고 false.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, availableTokens >= amount else { return false }
        state.spentTokens += amount
        return save()
    }

    // MARK: 사용량 적립

    /// 사용량 갱신. 앱 델리게이트가 매 새로고침마다 호출한다.
    ///
    /// `hasUsageData` 는 표시용 스냅샷 존재 여부이고, 전달된 map 은 오늘 날짜가 확인된
    /// 프로바이더 데이터만 담는다. 오래된 스냅샷이나 오늘 값이 없는 갱신은
    /// 장부 기준점을 움직일 관측으로 취급하지 않는다.
    func update(todayTokensByProvider: [String: Int], todayDate: String, hasUsageData: Bool) {
        if let remote {
            remote.recordUsage(todayTokensByProvider, date: todayDate, hasData: hasUsageData)
            return
        }
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
        return save()
    }

    // MARK: 카드 갈기

    /// 갈 수 있는 장수 — 보유분에서 한 장은 남긴다. 컬렉션에서 사라지면 안 된다.
    func spareCount(_ cardID: String) -> Int {
        let spares = max(0, cardCount(cardID) - 1)
        // 남는 장이 없으면 묶인 판형을 따질 것도 없다. 가지지 않은 카드까지 장부를 뒤지지 않는다.
        guard spares > 0, !protectedPrintings.isEmpty else { return spares }
        let unreserved = ownedPrintings(cardID: cardID).reduce(0) {
            $0 + max(0, $1.count - (protectedPrintings[$1.printing.storageKey] ?? 0))
        }
        return min(spares, unreserved)
    }

    private struct PrintingSaleLine {
        let printing: CardPrintingKey
        let count: Int
        let unitTokens: Int
    }

    /// 싼 인쇄본부터 팔 판매 계획. 상태를 바꾸지 않는다.
    private func lowestValueSalePlan(cardID: String, count: Int,
                                     prices: CardPrices?) -> [PrintingSaleLine] {
        var remaining = min(max(0, count), spareCount(cardID))
        guard remaining > 0 else { return [] }

        // 대표가만 있는 구형 가격표에서는 모든 판형 가격이 동률이다. 그때 문자열 순으로
        // 정렬하면 `holo`가 `normal`보다 먼저 팔려, 특별한 판형을 남긴다는 기대를 뒤집는다.
        // `allCases`는 보통 인쇄본부터 희귀 재질 순으로 선언되어 있으므로 그 순서를 안전한
        // 동률 해소 규칙으로 쓴다.
        let finishRank = Dictionary(uniqueKeysWithValues:
            CardFinish.allCases.enumerated().map { ($0.element, $0.offset) })
        let ordered = ownedPrintings(cardID: cardID).sorted { lhs, rhs in
            let left = MarketEconomy.usd(lhs.printing, prices: prices)
            let right = MarketEconomy.usd(rhs.printing, prices: prices)
            if left != right { return left < right }
            return finishRank[lhs.printing.finish, default: .max]
                < finishRank[rhs.printing.finish, default: .max]
        }

        var result: [PrintingSaleLine] = []
        for owned in ordered where remaining > 0 {
            let floor = protectedPrintings[owned.printing.storageKey] ?? 0
            let amount = min(max(0, owned.count - floor), remaining)
            guard amount > 0 else { continue }
            result.append(PrintingSaleLine(
                printing: owned.printing,
                count: amount,
                unitTokens: CardSale.price(cardID: cardID, finish: owned.printing.finish,
                                           prices: prices, perks: perks)))
            remaining -= amount
        }
        return result
    }

    /// 중복분을 전부 팔 때 받을 값. 실제 판매와 같은 최저가 판형 우선 계획을 쓴다.
    func spareSaleValue(cardID: String, prices: CardPrices? = CardPrices.shared) -> Int {
        lowestValueSalePlan(cardID: cardID, count: .max, prices: prices)
            .reduce(0) { $0 + $1.unitTokens * $1.count }
    }

    func serverSaleQuote(cardID: String, count: Int) -> Int {
        lowestValueSalePlan(cardID: cardID, count: count, prices: CardPrices.shared)
            .reduce(0) { $0 + $1.unitTokens * $1.count }
    }

    func normalizeServerPrintings() {
        let ledger = printingLedger
        for id in Array(state.cards.keys) { materializePrintings(cardID: id, ledger: ledger) }
    }

    /// Only the stdin server evaluator calls this after an atomic domain check.
    func serverTransfer(remove: [String: Int], add: [String: Int], credit: Int, debit: Int) throws {
        let maximum = 1_000_000_000_000_000
        guard credit >= 0, debit >= 0, credit <= maximum, debit <= availableTokens,
              state.marketEarnedTokens <= maximum - credit, state.marketSpentTokens <= maximum - debit else {
            throw LocalAudit.Failure(description: "Invalid market balance")
        }
        for (key, quantity) in remove {
            let printing = CardPrintingKey(storageKey: key)
            guard quantity > 0, (state.printingCards[key] ?? 0) - quantity >= max(1, protectedPrintings[key] ?? 0) else {
                throw LocalAudit.Failure(description: "Reserved or final printing")
            }
            state.printingCards[key, default: 0] -= quantity
            state.cards[printing.cardID, default: 0] -= quantity
        }
        for (key, quantity) in add {
            guard quantity > 0, quantity <= 1000 else { throw LocalAudit.Failure(description: "Invalid card transfer") }
            _ = addCard(CardPrintingKey(storageKey: key), count: quantity)
        }
        state.marketEarnedTokens += credit
        state.marketSpentTokens += debit
    }

    /// 옛 aggregate 수량을 normal 인쇄본으로 구체화해, 이후 감소를 정확히 기록할 수 있게 한다.
    ///
    /// `ledger` 는 여러 카드를 잇달아 고칠 때 처음에 한 번 묶어 둔 장부다. 카드 하나를 고치면 상태가
    /// 바뀌어 장부를 다시 묶어야 하는데, 카드끼리는 서로의 줄을 건드리지 않으므로 아직 고치지 않은
    /// 카드에는 처음 장부가 그대로 맞다. 같은 카드를 두 번 고칠 때는 넘기면 안 된다.
    private func materializePrintings(cardID: String, ledger: PrintingLedger? = nil) {
        let ledger = ledger ?? printingLedger
        let counts = ownedPrintingCounts(cardID: cardID, ledger: ledger)
        for storageKey in ledger.keys[cardID] ?? [] {
            state.printingCards.removeValue(forKey: storageKey)
        }
        for (finish, count) in counts where count > 0 {
            let key = CardPrintingKey(cardID: cardID, finish: finish).storageKey
            state.printingCards[key] = count
        }
    }

    private func apply(_ plan: [PrintingSaleLine], cardID: String, ledger: PrintingLedger? = nil) {
        guard !plan.isEmpty else { return }
        materializePrintings(cardID: cardID, ledger: ledger)
        for line in plan {
            let storageKey = line.printing.storageKey
            let left = (state.printingCards[storageKey] ?? 0) - line.count
            if left > 0 {
                state.printingCards[storageKey] = left
            } else {
                state.printingCards.removeValue(forKey: storageKey)
            }
        }
        state.cards[cardID] = max(1, cardCount(cardID) - plan.reduce(0) { $0 + $1.count })
    }

    /// 중복분을 판다. 받은 액수를 반환하고, 팔 것이 없으면 0.
    ///
    /// 시세의 절반을 쳐 준다(`CardSale`, 도감 판매 추가금이 있으면 그만큼 더). 마지막 한 장은
    /// 남긴다 — 수집한 카드가 컬렉션에서 없어지는 것은 되돌릴 수 없고, 실수로 그렇게 되면
    /// 잃은 것이 크다.
    @discardableResult
    func sellSpares(cardID: String, tier: CardTier, count: Int) -> Int {
        sellLowestValueSpares(cardID: cardID, tier: tier, count: count)
    }

    /// 중복분 중 가치가 낮은 인쇄본부터 판다. 어떤 판형 조합이어도 카드 번호별 마지막 한 장은
    /// 남긴다. 가격 주입은 미리보기·테스트가 같은 스냅샷을 쓰게 하기 위한 것이다.
    @discardableResult
    func sellLowestValueSpares(cardID: String, tier: CardTier, count: Int,
                               prices: CardPrices? = CardPrices.shared) -> Int {
        let plan = lowestValueSalePlan(cardID: cardID, count: count, prices: prices)
        guard !plan.isEmpty else { return 0 }

        apply(plan, cardID: cardID)
        let amount = plan.reduce(0) { $0 + $1.count }
        let refund = plan.reduce(0) { $0 + $1.unitTokens * $1.count }
        state.refundedTokens += refund
        state.cardsDisenchanted += amount
        guard save() else { return 0 }
        AppLog.write("sold \(amount)x \(cardID) (\(tier.rawValue), lowest printing first) for \(refund)")
        return refund
    }

    // MARK: 한번에 판매

    /// 한번에 판매의 결과. 미리보기와 실제 판매가 같은 값을 쓴다 —
    /// 미리 본 것과 실제로 팔린 것이 다르면 되돌릴 수 없는 동작에서 신뢰가 무너진다.
    struct BulkSale: Codable, Equatable, Sendable {
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
    /// `nil` is an explicit unlimited price range; collection filters still apply.
    static func bulkSaleTargets(_ entries: [CardEntry], maxWon: Int?,
                                spares: (String) -> Int,
                                prices: CardPrices? = CardPrices.shared) -> [String] {
        entries.compactMap { entry in
            guard spares(entry.id) > 0 else { return nil }
            guard let maxWon else { return entry.id }
            let usd = MarketEconomy.usd(cardID: entry.id, prices: prices)
            guard let prices, prices.krw(usd) <= maxWon else { return nil }
            return entry.id
        }
    }

    /// 팔면 무엇이 얼마인가. 상태를 바꾸지 않는다 — 화면이 매 프레임 부른다.
    func bulkSalePreview(_ targets: [String]) -> BulkSale {
        var seen = Set<String>()
        return targets.reduce(into: BulkSale()) { sale, cardID in
            guard seen.insert(cardID).inserted else { return }
            let plan = lowestValueSalePlan(cardID: cardID, count: .max,
                                           prices: CardPrices.shared)
            guard !plan.isEmpty else { return }
            sale.kinds += 1
            sale.copies += plan.reduce(0) { $0 + $1.count }
            sale.tokens += plan.reduce(0) { $0 + $1.unitTokens * $1.count }
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

        // 계획을 모두 세운 다음에 적용한다. 번갈아 하면 카드 하나를 팔 때마다 장부를 다시 묶는다.
        var seen = Set<String>()
        let plans = targets.compactMap { cardID -> (cardID: String, plan: [PrintingSaleLine])? in
            guard seen.insert(cardID).inserted else { return nil }
            return (cardID, lowestValueSalePlan(cardID: cardID, count: .max, prices: CardPrices.shared))
        }
        let ledger = printingLedger
        for entry in plans { apply(entry.plan, cardID: entry.cardID, ledger: ledger) }
        state.refundedTokens += sale.tokens
        state.cardsDisenchanted += sale.copies
        guard save() else { return .none }
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
        guard save() else { return false }
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
        if isOnline { updateRemotePreferences(favorite: .some(cardID)); return }
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

    /// 연출 미리보기의 NEW 판정용 읽기 전용 스냅샷. 반환값을 바꿔도 지갑은 변하지 않는다.
    var ownedCardIDs: Set<String> { Set(state.cards.keys) }

    /// 판형별 기록에 없는 aggregate 잔량은 옛 세이브에서 온 것이다.
    ///
    /// SIR·Radiant·Gold처럼 카드 자체가 한 판형으로 정해지는 경우에는 번들 rarity로 복원한다.
    /// Common·Uncommon·Rare처럼 reverse 여부를 알 수 없는 카드만 보수적으로 normal로 둔다.
    /// 상태를 바꾸지 않는 계산이라 업데이트 직후에도 기존 보유량을 그대로 읽을 수 있다.
    private func ownedPrintingCounts(cardID: String, ledger: PrintingLedger? = nil) -> [CardFinish: Int] {
        var result = (ledger ?? printingLedger).counts[cardID] ?? [:]
        let recorded = result.values.reduce(0, +)
        let legacy = max(0, cardCount(cardID) - recorded)
        if legacy > 0 {
            let entry = CardIndex.shared?.card(cardID)
            let finish = entry.map {
                CardFinishResolver.resolve(cardID: cardID,
                                           setID: $0.setID,
                                           originalRarity: $0.rarity,
                                           tier: $0.tier).finish
            } ?? .normal
            result[finish, default: 0] += legacy
        }
        return result
    }

    private var printingLedger: PrintingLedger {
        // 캐시를 써도 상태를 읽은 것으로 남겨, 상태가 바뀌면 이 값을 쓴 화면이 다시 그려지게 한다.
        let recorded = state.printingCards
        if let cached = printingLedgerCache { return cached }
        var ledger = PrintingLedger()
        ledger.counts.reserveCapacity(recorded.count)
        ledger.keys.reserveCapacity(recorded.count)
        for (storageKey, count) in recorded {
            let printing = CardPrintingKey(storageKey: storageKey)
            ledger.keys[printing.cardID, default: []].append(storageKey)
            if count > 0 { ledger.counts[printing.cardID, default: [:]][printing.finish, default: 0] += count }
        }
        printingLedgerCache = ledger
        return ledger
    }

    /// 특정 인쇄본 보유량. 옛 aggregate 잔량은 고유 판형을 복원하고, 모호할 때만 normal이다.
    func printingCount(_ printing: CardPrintingKey) -> Int {
        ownedPrintingCounts(cardID: printing.cardID)[printing.finish] ?? 0
    }

    func cardCount(_ cardID: String, finish: CardFinish) -> Int {
        printingCount(CardPrintingKey(cardID: cardID, finish: finish))
    }

    /// 카드 번호 하나에 대해 실제로 보유한 인쇄본 목록.
    func ownedPrintings(cardID: String) -> [(printing: CardPrintingKey, count: Int)] {
        ownedPrintingCounts(cardID: cardID)
            .filter { $0.value > 0 }
            .map { (CardPrintingKey(cardID: cardID, finish: $0.key), $0.value) }
    }

    /// 가진 인쇄본 중 시장가가 가장 높은 판형. 시세가 같거나 없으면 더 특수한 finish 를 택한다.
    func bestOwnedFinish(cardID: String,
                         prices: CardPrices? = CardPrices.shared) -> CardFinish? {
        let rank = Dictionary(uniqueKeysWithValues: CardFinish.allCases.enumerated().map { ($1, $0) })
        return ownedPrintings(cardID: cardID).max { lhs, rhs in
            let left = MarketEconomy.usd(lhs.printing, prices: prices)
            let right = MarketEconomy.usd(rhs.printing, prices: prices)
            if left != right { return left < right }
            return (rank[lhs.printing.finish] ?? 0) < (rank[rhs.printing.finish] ?? 0)
        }?.printing.finish
    }

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
    /// 지금 시세로 매긴 컬렉션 가치. 같은 상태와 시세면 지난 계산을 그대로 쓴다.
    func currentCollectionValueUSD() -> Double {
        let generation = PriceSnapshotStore.shared.currentGeneration
        // 캐시를 써도 상태를 읽은 것으로 남겨 상태가 바뀌면 화면이 다시 그려지게 한다.
        _ = state.cards.isEmpty
        if let cached = collectionValueCache, cached.prices == generation { return cached.value }
        let value = collectionValueUSD(prices: CardPrices.shared)
        collectionValueCache = (generation, value)
        return value
    }

    func collectionValueUSD(prices: CardPrices? = CardPrices.shared) -> Double {
        // `ownedPrintings(cardID:)` 를 카드마다 호출하면 그 안에서 `printingCards` 전체를
        // 다시 훑는다. 카드 2,103종·판형 812개인 실제 세이브에서는 카드를 한 장 넘길
        // 때마다 170만 회 이상 비교해 공개 애니메이션의 첫 프레임을 막았다.
        //
        // 판형 장부를 한 번만 집계하고 aggregate 장부의 레거시 잔량을 한 번 더 도는
        // O(printings + cards) 계산으로 같은 금액을 만든다. 저장 형식과 가격 규칙은 그대로다.
        var recordedByCard: [String: Int] = [:]
        recordedByCard.reserveCapacity(state.printingCards.count)
        var owned = 0.0

        for (storageKey, count) in state.printingCards where count > 0 {
            let printing = CardPrintingKey(storageKey: storageKey)
            // 기존 구현은 aggregate 장부에 있는 카드만 가치에 포함했다.
            guard state.cards[printing.cardID] != nil else { continue }
            recordedByCard[printing.cardID, default: 0] += count
            owned += MarketEconomy.usd(printing, prices: prices) * Double(count)
        }

        // 옛 세이브에는 판형 장부가 없거나 일부만 있다. 기록되지 않은 잔량은 기존과
        // 동일하게 카드 고유 판형을 복원하고, 모호한 카드만 normal 로 계산한다.
        for (cardID, totalCount) in state.cards where totalCount > 0 {
            let legacyCount = max(0, totalCount - recordedByCard[cardID, default: 0])
            guard legacyCount > 0 else { continue }
            let printing = inferredPrinting(cardID: cardID, entry: CardIndex.shared?.card(cardID))
            owned += MarketEconomy.usd(printing, prices: prices) * Double(legacyCount)
        }

        let held = unrevealedPrintings.reduce(0.0) { running, entry in
            let printing = CardPrintingKey(storageKey: entry.key)
            return running + MarketEconomy.usd(printing, prices: prices) * Double(entry.value)
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
    /// 아직 보지 않은 실제 판형. `unrevealed` 는 기존 화면용 aggregate로 함께 유지한다.
    private var unrevealedPrintings: [String: Int] = [:]

    /// 이 카드들을 아직 안 본 것으로 둔다.
    func holdForReveal(_ cardIDs: [String]) {
        holdForReveal(cardIDs.map { CardPrintingKey(cardID: $0) })
    }

    /// 이 인쇄본들을 아직 안 본 것으로 둔다. 판형별 가격이 공개를 앞질러 스포일러하지 않는다.
    func holdForReveal(_ printings: [CardPrintingKey]) {
        var held: [String: Int] = [:]
        var heldPrintings: [String: Int] = [:]
        for printing in printings {
            held[printing.cardID, default: 0] += 1
            heldPrintings[printing.storageKey, default: 0] += 1
        }
        unrevealed = held
        unrevealedPrintings = heldPrintings
    }

    /// 한 장을 봤다.
    func markRevealed(_ cardID: String) {
        guard let count = unrevealed[cardID] else { return }
        if count <= 1 { unrevealed.removeValue(forKey: cardID) } else { unrevealed[cardID] = count - 1 }

        // 옛 호출부는 판형을 모른다. 같은 카드의 첫 인쇄본 하나를 함께 연다.
        if let storageKey = unrevealedPrintings.keys.sorted().first(where: {
            CardPrintingKey(storageKey: $0).cardID == cardID
        }) {
            decrementUnrevealedPrinting(storageKey)
        }
    }

    func markRevealed(_ printing: CardPrintingKey) {
        guard let count = unrevealed[printing.cardID] else { return }
        if count <= 1 {
            unrevealed.removeValue(forKey: printing.cardID)
        } else {
            unrevealed[printing.cardID] = count - 1
        }
        decrementUnrevealedPrinting(printing.storageKey)
    }

    private func decrementUnrevealedPrinting(_ storageKey: String) {
        guard let count = unrevealedPrintings[storageKey] else { return }
        if count <= 1 {
            unrevealedPrintings.removeValue(forKey: storageKey)
        } else {
            unrevealedPrintings[storageKey] = count - 1
        }
    }

    /// 남은 전부를 봤다 — 요약 화면은 카드를 한꺼번에 보여 준다.
    func markAllRevealed() {
        guard !unrevealed.isEmpty else { return }
        unrevealed = [:]
        unrevealedPrintings = [:]
    }

    /// 개봉 결과를 수집함에 넣는다. 같은 카드가 여러 장 나오면 그만큼 쌓인다.
    ///
    /// 새로 완성된 도감을 함께 처리하고 그 목록을 돌려준다. 카드가 들어오는 경로가
    /// 여기뿐이라 판정을 여기 두면 호출부가 잊을 수 없다 — 화면마다 판정을 심으면
    /// 언젠가 한 곳이 빠지고, 그 화면으로 얻은 카드는 도감을 완성시키지 못한다.
    @discardableResult
    func collect(_ cardIDs: [String]) -> [DexCompletion] {
        collect(cardIDs.map { CardPrintingKey(cardID: $0) })
    }

    /// 인쇄본을 한 장 이상 수집한다. 기존 `cards` 합계와 새 `printingCards` 를 원자적으로
    /// 함께 올려, 옛 UI·도감과 새 판형 UI가 서로 다른 장수를 보지 않게 한다.
    @discardableResult
    func collect(_ printings: [CardPrintingKey]) -> [DexCompletion] {
        guard !printings.isEmpty else { return [] }
        let before = Set(state.cards.keys)
        let now = Int(Date().timeIntervalSince1970)
        // Thousands of card inserts should publish one state update, not one per field/card.
        var collected = state
        for printing in printings {
            let id = printing.cardID
            collected.cards[id, default: 0] += 1
            collected.printingCards[printing.storageKey, default: 0] += 1
            // 처음 얻은 때만 적는다. 두 번째부터 덮어쓰면 「최초」가 아니게 된다.
            if collected.cardFirstAt[id] == nil { collected.cardFirstAt[id] = now }
        }
        state = collected
        guard save() else { return [] }

        return DexProgress.newlyFilled(dexes: dexes, owned: { (state.cards[$0] ?? 0) > 0 },
                                       claimed: claimedDexIDs, before: before)
            .map { DexCompletion(dexID: $0.id, name: $0.name, tier: $0.tier) }
    }

    /// 한 인쇄본을 여러 장 넣는 편의 API. 도감 완성 판정과 저장은 `collect` 와 동일하다.
    @discardableResult
    func addCard(_ printing: CardPrintingKey, count: Int = 1) -> [DexCompletion] {
        guard count > 0 else { return [] }
        return collect(Array(repeating: printing, count: count))
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
        if isOnline { return state.oripa ?? OripaBox(cards: [], serial: 0) }
        // 봉투 수가 맞지 않는 박스는 버린다. 구성표를 바꾼 배포에서 넘어온 옛 박스라
        // 그대로 두면 격자가 넘치거나 값이 구성표와 어긋난다.
        if let box = state.oripa, !box.isEmpty, box.cards.count == OripaConfig.slotsPerBox {
            return box
        }
        state.oripa = freshOripaBox(index: index)
        save()
        return state.oripa ?? freshOripaBox(index: index)
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
        if let remote { Task { _ = await remote.execute(.init(kind: "refresh_oripa"), expectedTokens: 0) }; return }
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
        let result = transaction(failure: Optional<(card: PulledCard, completions: [DexCompletion])>.none) {
            pullOripaTransaction(index: index, envelope: envelope)
        }
        if let result { holdForReveal([CardPrintingKey(cardID: result.card.id, finish: result.card.finish)]) }
        return result
    }

    private func pullOripaTransaction(index: CardIndex, envelope: Int)
        -> (card: PulledCard, completions: [DexCompletion])? {
        var box = oripaBox(index: index)
        guard box.cards.indices.contains(envelope), !box.opened.contains(envelope),
              spend(oripaPrice(index: index)) else { return nil }

        guard let id = Oripa.open(envelope, in: &box) else { return nil }
        let isNew = cardCount(id) == 0
        state.oripa = box
        let entry = index.card(id)
        let printing = inferredPrinting(cardID: id, entry: entry)
        let completions = collect([printing])   // 저장까지 여기서 한다
        // 가림막을 걷기 전까지는 값을 올리지 않는다 — 오리파도 뒤집어 보는 연출이다.
        AppLog.write("oripa opened \(envelope) -> \(id) box=\(box.serial) remaining=\(box.remaining)")
        return (PulledCard(id: id, tier: entry?.tier ?? .doubleRare, isNew: isNew,
                           finish: printing.finish),
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

    /// 도감 칭호를 고른다. 레벨 칭호는 내려놓는다 — 칭호는 하나만 단다.
    func setTitle(_ completed: Int?) {
        if isOnline {
            updateRemotePreferences(title: .some(completed),
                                    levelTitle: completed == nil ? .some(state.levelTitle) : .some(nil))
            return
        }
        state.title = completed
        if completed != nil { state.levelTitle = nil }
        save()
    }

    // MARK: 트레이너 레벨

    /// 지금 레벨. 연 팩 수에서 계산한다.
    var level: Int { LevelRules.level(forPacksOpened: state.packsOpened) }
    var packsOpenedTotal: Int { state.packsOpened }

    /// 아직 받지 않은 레벨 보상. 2레벨부터 지금 레벨까지다.
    var claimableLevels: [Int] {
        let current = level
        guard current >= 2 else { return [] }
        let claimed = Set(state.claimedLevels)
        return (2...current).filter { !claimed.contains($0) }
    }

    /// 받을 수 있는 레벨 보상을 한꺼번에 받는다. 받은 보상 목록을 돌려준다.
    @discardableResult
    func claimLevels() -> [LevelRules.Reward] {
        transaction(failure: []) { claimLevelsTransaction() }
    }

    private func claimLevelsTransaction() -> [LevelRules.Reward] {
        var rewards: [LevelRules.Reward] = []
        for level in claimableLevels {
            let reward = LevelRules.reward(for: level)
            state.packs[reward.setID, default: 0] += reward.packs
            if reward.couponCount > 0 {
                if let i = state.coupons.firstIndex(where: { $0.setID == reward.setID
                                                             && $0.value == reward.couponValue }) {
                    state.coupons[i].left += reward.couponCount
                } else {
                    state.coupons.append(PackCoupon(setID: reward.setID, value: reward.couponValue,
                                                    left: reward.couponCount))
                }
            }
            state.claimedLevels.append(level)
            rewards.append(reward)
        }
        if !rewards.isEmpty {
            AppLog.write("levels claimed \(rewards.map(\.level)) packs=\(rewards.reduce(0) { $0 + $1.packs })")
        }
        return rewards
    }

    func claimLevelsOnlineAware() async -> [LevelRules.Reward]? {
        guard let remote else { return claimLevels() }
        let pending = claimableLevels
        guard !pending.isEmpty else { return [] }
        let result = await remote.execute(.init(kind: "claim_levels"))
        persistenceError = remote.error
        guard result != nil else { return nil }
        return pending.map(LevelRules.reward(for:))
    }

    /// 열린 레벨 칭호. 그 레벨에 닿으면 열린다.
    var levelTitles: [Int] { LevelRules.titleLevels.filter { level >= $0 } }
    var levelTitleChoice: Int? { state.levelTitle }

    /// 레벨 칭호를 고른다. 도감 칭호는 내려놓는다.
    func setLevelTitle(_ level: Int?) {
        if isOnline {
            updateRemotePreferences(title: level == nil ? .some(state.title) : .some(nil),
                                    levelTitle: .some(level))
            return
        }
        state.levelTitle = level
        if level != nil { state.title = nil }
        save()
    }

    /// 화면에 다는 칭호. 레벨 칭호를 골랐으면 그것, 아니면 도감 칭호다.
    func displayTitle(_ l: L) -> String? {
        if let picked = state.levelTitle, levelTitles.contains(picked) { return l.levelTitle(picked) }
        return title?.text(language)
    }

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

    /// 할인 전 정가. 쿠폰이 있으면 상점이 이 값에 줄을 그어 보여 준다.
    ///
    /// 영구 할인과 쿠폰은 서로 겹치지 않는다. 쿠폰 문구가 「정가에서 50%」를 뜻해야 하고,
    /// 둘을 곱하면 팩을 사서 바로 파는 것만으로 잔액이 늘어나는 세트가 생기기 때문이다.
    func listPrice(setID: String, index: CardIndex) -> Int {
        PackPricing.basePrice(setID: setID, index: index, prices: CardPrices.shared)
    }

    /// **실제로 낼 값.** 쿠폰이 있으면 그만큼 더 깎인다.
    ///
    /// 쿠폰은 한 번에 한 장씩 쓰이므로, 여러 개를 살 때는 쿠폰이 있는 만큼만 할인된다.
    /// 그래서 총액은 낱개 값의 곱이 아니라 이 함수로 세어야 한다.
    func packTotal(setID: String, count: Int, index: CardIndex) -> Int {
        let list = listPrice(setID: setID, index: index)
        let permanent = PackPricing.price(setID: setID, index: index, perks: perks)
        var remaining = max(0, count)
        var total = 0

        // 실제 소모 순서와 같이 센 쿠폰부터 쓴다. 50% 한 장과 25% 네 장을 가졌다고
        // 다섯 팩 모두 50%로 계산하면 표시 총액보다 적게 차감되는 경제 버그가 된다.
        let coupons = state.coupons
            .filter { $0.setID == setID && $0.left > 0 }
            .sorted { $0.value > $1.value }
        for coupon in coupons where remaining > 0 {
            let used = min(remaining, coupon.left)
            let effectiveDiscount = max(perks.packDiscount, coupon.value)
            let cut = MarketEconomy.quantized(
                Int((Double(list) * (1 - effectiveDiscount)).rounded())
            )
            total += cut * used
            remaining -= used
        }
        return total + permanent * remaining
    }

    /// 현재 잔액으로 살 수 있는 최대 수량. UI 편의용 20개 상한은 두지 않는다.
    /// 쿠폰은 실제 소비 순서대로 계산하고, 그 뒤의 수량은 영구 할인가로 센다.
    func maximumAffordablePackCount(setID: String, index: CardIndex) -> Int {
        var budget = max(0, availableTokens)
        guard budget > 0 else { return 0 }

        let list = listPrice(setID: setID, index: index)
        let permanent = max(1, PackPricing.price(setID: setID, index: index, perks: perks))
        var affordable = 0
        let coupons = state.coupons
            .filter { $0.setID == setID && $0.left > 0 }
            .sorted { $0.value > $1.value }

        for coupon in coupons {
            let effectiveDiscount = max(perks.packDiscount, coupon.value)
            let couponPrice = max(1, MarketEconomy.quantized(
                Int((Double(list) * (1 - effectiveDiscount)).rounded())
            ))
            let purchased = min(coupon.left, budget / couponPrice)
            affordable += purchased
            budget -= purchased * couponPrice
            if purchased < coupon.left { return affordable }
        }

        return affordable + budget / permanent
    }

    /// 낱개 값 — 쿠폰이 있으면 쿠폰가다. 상점이 큰 글씨로 적는 값이다.
    func packPrice(setID: String, index: CardIndex) -> Int {
        let rate = couponDiscount(setID: setID)
        guard rate > 0 else {
            return PackPricing.price(setID: setID, index: index, perks: perks)
        }
        let list = listPrice(setID: setID, index: index)
        let effectiveDiscount = max(perks.packDiscount, rate)
        return MarketEconomy.quantized(
            Int((Double(list) * (1 - effectiveDiscount)).rounded())
        )
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
        transaction(failure: Optional<DexClaim>.none) {
            claimTransaction(dexID, step: step, index: index)
        }
    }

    private func claimTransaction(_ dexID: String, step: Int,
                                  index: CardIndex?) -> DexClaim? {
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
        _ = collect([inferredPrinting(cardID: picked.id, entry: picked)])
        return picked.id
    }

    /// 슬롯 힌트가 없는 단일 카드 보상은 원본 rarity로 기본 판형을 정한다.
    private func inferredPrinting(cardID: String, entry: CardEntry?) -> CardPrintingKey {
        guard let entry else { return CardPrintingKey(cardID: cardID) }
        let finish = CardFinishResolver.resolve(cardID: cardID,
                                                setID: entry.setID,
                                                originalRarity: entry.rarity,
                                                tier: entry.tier).finish
        return CardPrintingKey(cardID: cardID, finish: finish)
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
        guard count > 0, total > 0, availableTokens >= total else { return false }
        state.spentTokens += total
        state.packs[setID, default: 0] += count
        consumeCoupons(setID: setID, times: count)
        return save()
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
        if let remote {
            if limitsReady && remote.ready && !remote.busy {
                let report = windows.map { window in
                    ServerRulesBridge.Window(key: window.key, name: window.name,
                        kind: window.kind == .weekly ? "weekly" : "session",
                        utilization: window.utilization,
                        instance: window.instance.isEmpty ? "" : Self.privateInstance(window.instance))
                }
                Task { _ = await remote.execute(.init(kind: "report_bonus", windows: report)) }
            }
            return []
        }
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
            || state.packGrantedInstances != beforeInstances {
            if !save() { lastGrant = nil; return [] }
        }
        return grants
    }

    // MARK: Server-authoritative commands

    var resourceActionsDisabled: Bool { savingBlocked || isOpeningPacks || (remote.map { !$0.ready || $0.busy || $0.hasPending || $0.hasOnlinePending } ?? false) }

    /// Only the isolated server evaluator calls this; the HTTP layer owns the
    /// device high-water mark and supplies a validated, nonnegative delta.
    func creditReportedTokens(_ delta: Int) {
        guard !isOnline, delta >= 0 else { return }
        state.installBaselineSet = true
        accrue(delta)
        save()
    }

    private static func privateInstance(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func updateRemotePreferences(mode: OpeningMode? = nil,
                                         favorite: String?? = nil, title: Int?? = nil,
                                         levelTitle: Int?? = nil) {
        guard let remote else { return }
        let command = ServerRulesBridge.Command(kind: "set_preferences",
            opening_mode: (mode ?? state.openingMode).rawValue,
            favorite_card_id: favorite ?? state.favoriteCardID,
            title: title ?? state.title,
            level_title: levelTitle ?? state.levelTitle)
        Task { _ = await remote.execute(command); persistenceError = remote.error }
    }

    func purchasePacks(setID: String, count: Int, total: Int) async -> Bool {
        guard let remote else { return buyPacks(setID: setID, count: count, total: total) }
        guard count > 0 else { return false }
        guard let index = CardIndex.shared, total == packTotal(setID: setID, count: count, index: index) else {
            persistenceError = l.packPriceChanged
            return false
        }
        var remaining = count
        while remaining > 0 {
            let chunk = min(remaining, 1000)
            guard await remote.execute(.init(kind: "buy_packs", set_id: setID, count: chunk), expectedTokens: packTotal(setID: setID, count: chunk, index: index)) != nil else {
                persistenceError = l.packsBoughtPartly(count - remaining, of: count, reason: remote.error)
                return false
            }
            remaining -= chunk
        }
        return true
    }

    func sellSparesOnlineAware(cardID: String, tier: CardTier, count: Int) async -> Int {
        guard let remote else { return sellSpares(cardID: cardID, tier: tier, count: count) }
        var remaining = count
        var refund = 0
        while remaining > 0 {
            let chunk = min(remaining, 1000)
            guard let result = await remote.execute(.init(kind: "sell_spares", count: chunk, card_id: cardID), expectedTokens: serverSaleQuote(cardID: cardID, count: chunk)) else {
                persistenceError = remote.error
                break
            }
            refund += result.tokens ?? 0
            remaining -= chunk
        }
        return refund
    }

    func sellBulkOnlineAware(_ cardIDs: [String]) async -> BulkSale {
        guard let remote else { return sellSpares(cardIDs) }
        let ids = Array(Set(cardIDs)).sorted()
        var total = BulkSale.none
        for start in stride(from: 0, to: ids.count, by: 1000) {
            let chunk = Array(ids[start..<min(start + 1000, ids.count)])
            guard let result = await remote.execute(.init(kind: "sell_bulk", card_ids: chunk), expectedTokens: chunk.reduce(0) { $0 + spareSaleValue(cardID: $1) }),
                  let sale = result.bulk else { persistenceError = remote.error; break }
            total.kinds += sale.kinds
            total.copies += sale.copies
            total.tokens += sale.tokens
        }
        return total
    }

    func claimDexOnlineAware(_ dexID: String, step: Int) async -> DexClaim? {
        guard let remote else { return claim(dexID, step: step) }
        let result = await remote.execute(.init(kind: "claim_dex", dex_id: dexID, step: step))
        persistenceError = remote.error
        return result?.dex
    }

    func pullOripaOnlineAware(index: CardIndex, envelope: Int) async -> ServerRulesBridge.OripaResult? {
        guard let remote else {
            return pullOripa(index: index, envelope: envelope).map {
                ServerRulesBridge.OripaResult(card: $0.card, completions: $0.completions)
            }
        }
        let result = await remote.execute(.init(kind: "pull_oripa", envelope: envelope), expectedTokens: oripaPrice(index: index))?.oripa
        persistenceError = remote.error
        if let result { holdForReveal([CardPrintingKey(cardID: result.card.id, finish: result.card.finish)]) }
        return result
    }

    private func openRemotePacks(setID: String, count: Int) async -> OpenedPackBatch? {
        guard let remote, !isOpeningPacks, count > 0, packCount(setID: setID) >= count else { return nil }
        isOpeningPacks = true
        defer { isOpeningPacks = false }
        var packs: [OpenedCards] = []
        var completions: [DexCompletion] = []
        var openingJob: RemoteGameSession.OpeningJob?
        if count > 1000 {
            do { openingJob = try await remote.createOpeningJob(setID: setID, count: count) }
            catch { persistenceError = ProblemText.message(for: error); return nil }
        }
        while packs.count < count, !Task.isCancelled {
            let chunk = min(count - packs.count, 1000)
            let batch: OpenedPackBatch
            if let job = openingJob {
                do {
                    let reply = try await remote.advanceOpeningJob(job)
                    openingJob = reply.job
                    guard let opened = reply.packs else { throw RemoteGameSession.Failure(message: l.noOpeningResult) }
                    batch = opened
                } catch {
                    persistenceError = l.openingJobPaused(packs.count, of: count, reason: ProblemText.message(for: error))
                    break
                }
            } else {
                guard let result = await remote.execute(.init(kind: "open_packs", set_id: setID, count: chunk)),
                      let opened = result.packs else {
                    persistenceError = l.packsOpenedPartly(packs.count, of: count, reason: remote.error)
                    break
                }
                batch = opened
            }
            packs.append(contentsOf: batch.packs)
            completions.append(contentsOf: batch.completions)
        }
        guard !packs.isEmpty else { return nil }
        let batch = OpenedPackBatch(packs: packs, completions: completions)
        holdForReveal(batch.cards.filter { CardIndex.shared?.card($0.id) != nil }
            .map { CardPrintingKey(cardID: $0.id, finish: $0.finish) })
        return batch
    }

    // MARK: 영속

    /// Draw, consume, collect, pity and audit trail either all commit or none do.
    func openPack(setID: String, index: CardIndex, seed: UInt64? = nil)
        -> (opened: OpenedCards, completions: [DexCompletion])? {
        guard let batch = openPacks(setID: setID, count: 1, index: index,
                                    seeds: seed.map { [$0] }),
              let opened = batch.packs.first else { return nil }
        return (opened, batch.completions)
    }

    /// 여러 팩을 한 번에 연다. 중간 팩에서 저장이 실패해도 일부만 소비되지 않도록 전체를
    /// 하나의 트랜잭션으로 커밋한다. 각 팩은 직전 팩이 갱신한 보유 카드와 천장을 이어받는다.
    func openPacks(setID: String, count: Int, index: CardIndex,
                   seeds: [UInt64]? = nil) -> OpenedPackBatch? {
        guard !isOpeningPacks, count > 0, packCount(setID: setID) >= count else { return nil }
        guard seeds == nil || seeds?.count == count else { return nil }
        do {
            let prepared = try PreparedPackBatch.draw(setID: setID, count: count, index: index,
                owned: Set(state.cards.keys), mode: state.openingMode, perks: openingPerks,
                pity: pity(setID: setID), seeds: seeds)
            return commitOpening(prepared, setID: setID, count: count, mode: state.openingMode)
        } catch {
            persistenceError = ProblemText.message(for: error)
            return nil
        }
    }

    /// UI entry point. Preparation never touches the live wallet; only a validated complete
    /// result commits on the main actor. Cancellation before commit consumes nothing.
    func openPacksAsync(setID: String, count: Int, index: CardIndex,
                        seeds: [UInt64]? = nil) async -> OpenedPackBatch? {
        if isOnline { return await openRemotePacks(setID: setID, count: count) }
        guard !isOpeningPacks, !savingBlocked, count > 0, packCount(setID: setID) >= count,
              seeds == nil || seeds?.count == count, !Task.isCancelled else { return nil }
        isOpeningPacks = true
        defer { isOpeningPacks = false }
        let mode = state.openingMode
        let perks = openingPerks
        let cardsBefore = state.cards
        let pityBefore = pity(setID: setID)
        let worker = Task.detached(priority: .userInitiated) {
            try PreparedPackBatch.draw(setID: setID, count: count, index: index,
                owned: Set(cardsBefore.keys), mode: mode, perks: perks, pity: pityBefore, seeds: seeds)
        }
        do {
            let prepared = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            // Other screens may sell cards/change mode while preparation is running. Never
            // overwrite those edits or commit NEW/pity results derived from a stale snapshot.
            guard state.cards == cardsBefore, state.openingMode == mode, openingPerks == perks,
                  pity(setID: setID) == pityBefore, packCount(setID: setID) >= count else {
                persistenceError = l.openingStateChanged
                return nil
            }
            return commitOpening(prepared, setID: setID, count: count, mode: mode)
        } catch is CancellationError {
            return nil
        } catch {
            persistenceError = ProblemText.message(for: error)
            return nil
        }
    }

    private func commitOpening(_ prepared: PreparedPackBatch, setID: String, count: Int,
                               mode: OpeningMode) -> OpenedPackBatch? {
        let result = transaction(failure: Optional<OpenedPackBatch>.none) {
            let remaining = packCount(setID: setID) - count
            if remaining == 0 { state.packs.removeValue(forKey: setID) }
            else { state.packs[setID] = remaining }
            state.packsOpened += count

            let completions = collect(prepared.printings)
            if mode == .game { setPity(prepared.pity, setID: setID) }
            state.openingHistory.append(contentsOf: prepared.records)
            if state.openingHistory.count > OpeningRules.historyLimit {
                state.openingHistory.removeFirst(state.openingHistory.count - OpeningRules.historyLimit)
            }
            return OpenedPackBatch(packs: prepared.packs, completions: completions)
        }
        if result != nil { holdForReveal(prepared.printings) }
        return result
    }

    private func load() {
        do {
            let loaded = try GamePersistence(url: fileURL).load()
            state = loaded.state
            durableState = state
            recoveredSave = loaded.recovered
        } catch {
            savingBlocked = true
            persistenceError = ProblemText.message(for: error)
            AppLog.write("game state protected: \(error.localizedDescription)")
            return
        }
        if reconcilePrintingCards() { save() }
        backfillFirstAcquired()
    }

    /// 인쇄본 장부는 aggregate 장부보다 구체적이므로, 둘이 어긋났을 때 어느 쪽도 버리지 않는다.
    /// bare legacy key는 normal storage key로 정규화하고 인쇄본 합이 더 크면 aggregate를 올린다.
    @discardableResult
    private func reconcilePrintingCards() -> Bool {
        var canonical: [String: Int] = [:]
        var totals: [String: Int] = [:]
        for (storageKey, count) in state.printingCards where count > 0 {
            let printing = CardPrintingKey(storageKey: storageKey)
            canonical[printing.storageKey, default: 0] += count
            totals[printing.cardID, default: 0] += count
        }

        var changed = canonical != state.printingCards
        state.printingCards = canonical
        for (cardID, total) in totals where total > cardCount(cardID) {
            state.cards[cardID] = total
            changed = true
        }
        return changed
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

    @discardableResult
    private func save() -> Bool {
        if isOnline {
            state = durableState
            refreshPerks()
            persistenceError = l.onlineChangesThroughServer
            return false
        }
        if transactionDepth > 0 { return !savingBlocked }
        do {
            guard !savingBlocked else { throw GamePersistence.Failure.unrecoverable }
            if let commitState { try commitState(state) }
            else { try GamePersistence(url: fileURL).commit(state) }
            durableState = state
            persistenceError = nil
            return true
        } catch {
            state = durableState
            refreshPerks()
            persistenceError = ProblemText.message(for: error)
            AppLog.write("game transaction cancelled: \(error.localizedDescription)")
            return false
        }
    }

    /// Nested legacy mutators may stage saves, but only the outer operation commits.
    private func transaction<T>(failure: T, _ body: () -> T) -> T {
        guard !savingBlocked else { return failure }
        transactionDepth += 1
        let result = body()
        transactionDepth -= 1
        guard save() else { return failure }
        return result
    }
}
