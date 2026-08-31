import XCTest
@testable import PokePackBar

/// 결과를 고정하기 위한 결정적 난수 생성기. 확률 로직 검증에 쓴다.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        // splitmix64 — 짧고 분포가 고르다.
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@MainActor
final class WalletStoreTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wallet-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeStore() -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
    }

    // MARK: 설치 기준선

    /// 데이터가 도착하기 전에는 기준선을 잡지 않는다. 잡아 버리면 그날의 과거 사용량이
    /// 다음 정상 갱신에서 전부 신규 사용량으로 적립된다.
    func testBaselineNotSetWithoutUsageData() {
        let s = makeStore()
        s.update(todayTokensByProvider: [:], todayDate: "2026-08-26", hasUsageData: false)
        XCTAssertTrue(s.awaitingFirstUsage)
        XCTAssertEqual(s.availableTokens, 0)
    }

    /// 첫 유효 관측은 기준점으로만 저장한다 — 설치 이전 사용량을 재화로 주지 않는다.
    func testFirstObservationSeedsBaselineWithoutGranting() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["claude_code": 500_000], todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertFalse(s.awaitingFirstUsage)
        XCTAssertEqual(s.usedSinceInstall, 0, "설치 전 사용량은 소급 지급하지 않는다")
    }

    /// 기준선 이후 증가분만 적립한다.
    func testAccruesOnlyIncrementAfterBaseline() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["claude_code": 100], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["claude_code": 350], todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 250)
    }

    // MARK: 프로바이더별 장부

    /// 새로 관측된 프로바이더의 과거 로그를 소급하지 않는다. 그러지 않으면 도구를
    /// 하나 새로 쓰기 시작한 날 그 도구의 하루치가 통째로 적립된다.
    func testNewProviderIsSeededNotGranted() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["claude_code": 100], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["claude_code": 150, "codex": 900_000],
                 todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 50, "codex 는 seed 만 되고 적립되지 않아야 한다")

        s.update(todayTokensByProvider: ["claude_code": 150, "codex": 900_100],
                 todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 150, "이후 증가분부터 적립된다")
    }

    /// 한 프로바이더 값이 역행하면 그 줄만 기준을 다시 잡는다.
    /// 전체 합계를 rebase 하면 다른 프로바이더의 정상 증가분이 함께 사라진다.
    func testRegressionRebasesOnlyThatProvider() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 100, "b": 100], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 40, "b": 160], todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 60, "b 의 증가분 60 은 살아야 한다")
    }

    /// 오래된 스냅샷이나 빈 갱신으로 장부를 움직이지 않는다.
    func testEmptyRefreshDoesNotDisturbLedger() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 100], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: [:], todayDate: "2026-08-27", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 130], todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 30)
    }

    // MARK: 날짜 전환

    /// 날짜가 바뀌면 그날의 누적값 전체를 새 날짜 사용량으로 적립한다.
    /// 일자별 스냅샷은 서로 비교할 수 없기 때문이다.
    func testDateChangeAccruesFullDayTotal() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 100], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 500], todayDate: "2026-08-26", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 400)

        s.update(todayTokensByProvider: ["a": 70], todayDate: "2026-08-27", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 470, "새 날짜의 누적값이 그대로 적립된다")
    }

    /// 날짜가 바뀐 첫 갱신에서 이전 프로바이더가 빠져도, 같은 날 복구되면 사용량을 적립해야 한다.
    /// 장부에서 제거해 버리면 복구 시 현재값이 '이미 적립한 값'으로 seed 되어 하루치가 누락된다.
    func testProviderMissingOnDateRollThenRecoveringStillAccrues() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 100, "b": 100], todayDate: "2026-08-26", hasUsageData: true)
        // 날짜 전환 첫 갱신에 b 가 빠졌다.
        s.update(todayTokensByProvider: ["a": 10], todayDate: "2026-08-27", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 10)
        // 같은 날 b 가 복구됐다. 그날 b 사용량 80 이 적립돼야 한다.
        s.update(todayTokensByProvider: ["a": 10, "b": 80], todayDate: "2026-08-27", hasUsageData: true)
        XCTAssertEqual(s.usedSinceInstall, 90)
    }

    // MARK: 지출

    /// 개봉 연출이 끝나기 전에는 컬렉션 가치가 오르지 않는다.
    ///
    /// 카드는 뽑는 순간 수집함에 들어간다(연출 중에 팝오버를 닫아도 잃지 않아야 한다).
    /// 그런데 머리글의 컬렉션 가치는 늘 보이므로, 값이 먼저 오르면 카드를 뒤집기 전에
    /// 무엇이 나왔는지 알게 된다 — 스포일러다.
    func testHeldCardsStayOutOfTheCollectionValue() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let cards = Array(index.cards.prefix(3).map(\.id))

        s.collect(cards)
        let full = s.collectionValueUSD(prices: prices)
        XCTAssertGreaterThan(full, 0)

        s.holdForReveal(cards)
        XCTAssertEqual(s.collectionValueUSD(prices: prices), 0, accuracy: 1e-9,
                       "아직 안 본 카드가 값에 들어갔다")

        s.markRevealed(cards[0])
        let partial = s.collectionValueUSD(prices: prices)
        XCTAssertGreaterThan(partial, 0)
        XCTAssertLessThan(partial, full, "한 장만 봤는데 전부 반영됐다")

        s.markAllRevealed()
        XCTAssertEqual(s.collectionValueUSD(prices: prices), full, accuracy: 1e-9)
        // 카드 자체는 처음부터 들어 있다 — 감춘 것은 값 표시뿐이다.
        XCTAssertEqual(s.distinctCardCount, cards.count)
    }

    func testSpendDeductsFromBalanceButNotFromLifetime() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 0], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 1000], todayDate: "2026-08-26", hasUsageData: true)

        XCTAssertTrue(s.spend(400))
        XCTAssertEqual(s.availableTokens, 600)
        XCTAssertEqual(s.usedSinceInstall, 1000, "누적 사용량은 통계이므로 되감지 않는다")
    }

    func testSpendRejectsOverdraftAndNonPositive() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 0], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 100], todayDate: "2026-08-26", hasUsageData: true)

        XCTAssertFalse(s.spend(101))
        XCTAssertFalse(s.spend(0))
        XCTAssertEqual(s.availableTokens, 100)
    }

    // MARK: 보유량

    func testPackAndCardInventory() {
        let s = makeStore()
        s.addPack(setID: "sv10", count: 2)
        XCTAssertEqual(s.packCount(setID: "sv10"), 2)

        XCTAssertTrue(s.consumePack(setID: "sv10"))
        XCTAssertEqual(s.packCount(setID: "sv10"), 1)
        XCTAssertTrue(s.consumePack(setID: "sv10"))
        XCTAssertFalse(s.consumePack(setID: "sv10"), "없는 팩은 소비되지 않는다")
        XCTAssertEqual(s.state.packsOpened, 2)
        XCTAssertTrue(s.ownedPacks.isEmpty, "0 이 된 항목은 목록에서 빠진다")

        s.collect(["sv10-1", "sv10-1", "sv10-2"])
        XCTAssertEqual(s.cardCount("sv10-1"), 2)
        XCTAssertEqual(s.distinctCardCount, 2)
        XCTAssertEqual(s.totalCardCount, 3)
    }

    // MARK: 영속

    func testStateSurvivesReload() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 0], todayDate: "2026-08-26", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 900], todayDate: "2026-08-26", hasUsageData: true)
        s.spend(200)
        s.addPack(setID: "base1")
        s.collect(["base1-4"])

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.availableTokens, 700)
        XCTAssertEqual(reloaded.packCount(setID: "base1"), 1)
        XCTAssertEqual(reloaded.cardCount("base1-4"), 1)
    }

    /// 손상된 파일은 새로 시작하되 원본을 보존한다. 덮어써 버리면 복구 여지가 없다.
    func testCorruptStateIsBackedUpNotOverwritten() throws {
        let file = dir.appendingPathComponent("game-state.json")
        try Data("not json at all".utf8).write(to: file)

        let s = makeStore()
        XCTAssertEqual(s.availableTokens, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.appendingPathExtension("corrupt").path))
    }

    // MARK: 보너스 팩

    /// 첫 실행에는 이미 100% 인 창에 소급 지급하지 않는다. 시드만 한다.
    func testFirstRunSeedsWithoutGranting() {
        let s = makeStore()
        let w = [BonusWindow(key: "claude.fiveHour", name: "5h", kind: .session, utilization: 100)]
        s.grantBonusPacks(from: w, limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(s.totalPackCount, 0)
        XCTAssertTrue(s.state.packGrantSeeded)
    }

    /// 시드 이후 100% 를 새로 넘어선 순간에만 지급하고, 같은 창에서 재지급하지 않는다.
    func testGrantsOnceOnRisingEdge() {
        let s = makeStore()
        let key = "claude.fiveHour"
        // 시드 (아직 100% 미만)
        s.grantBonusPacks(from: [BonusWindow(key: key, name: "5h", kind: .session, utilization: 40)],
                          limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(s.totalPackCount, 0)

        let full = [BonusWindow(key: key, name: "5h", kind: .session, utilization: 100)]
        s.grantBonusPacks(from: full, limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(s.totalPackCount, PackConfig.bonusPackCount)

        s.grantBonusPacks(from: full, limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(s.totalPackCount, PackConfig.bonusPackCount, "같은 창에서 재지급하지 않는다")
    }

    /// 창이 100% 아래로 내려가면 다시 무장되고, 다음 도달에 또 지급한다.
    /// 재무장 상태가 영속되지 않으면 재시작 후 지급이 누락된다.
    func testReArmsAfterDroppingBelowFullAndPersists() {
        let s = makeStore()
        let key = "claude.fiveHour"
        func windows(_ u: Double) -> [BonusWindow] {
            [BonusWindow(key: key, name: "5h", kind: .session, utilization: u)]
        }
        s.grantBonusPacks(from: windows(10), limitsReady: true, availableSets: ["sv10"])
        s.grantBonusPacks(from: windows(100), limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(s.totalPackCount, PackConfig.bonusPackCount)

        s.grantBonusPacks(from: windows(5), limitsReady: true, availableSets: ["sv10"])   // 재무장
        // 재시작을 흉내낸다 — 재무장이 저장돼 있어야 다음 도달에 지급된다.
        let reloaded = makeStore()
        reloaded.grantBonusPacks(from: windows(100), limitsReady: true, availableSets: ["sv10"])
        XCTAssertEqual(reloaded.totalPackCount, PackConfig.bonusPackCount * 2)
    }

    /// 한도가 아직 로드되지 않았으면 시드도 지급도 하지 않는다.
    func testWaitsUntilLimitsReady() {
        let s = makeStore()
        let w = [BonusWindow(key: "k", name: "5h", kind: .session, utilization: 100)]
        s.grantBonusPacks(from: w, limitsReady: false, availableSets: ["sv10"])
        XCTAssertFalse(s.state.packGrantSeeded)
        XCTAssertEqual(s.totalPackCount, 0)
    }

    /// 지급할 세트 목록이 비면 아무 일도 하지 않는다 — 인덱스 로드 실패 시 무장이 소진되면 안 된다.
    func testNoSetsMeansNoSeedAndNoGrant() {
        let s = makeStore()
        let w = [BonusWindow(key: "k", name: "5h", kind: .session, utilization: 100)]
        s.grantBonusPacks(from: w, limitsReady: true, availableSets: [])
        XCTAssertFalse(s.state.packGrantSeeded)
    }

    /// 판정은 순수 함수라 난수를 고정하면 결과가 재현된다.
    func testEvaluateGrantsIsDeterministicWithSeededGenerator() {
        var tier: [String: Int] = [:]
        var g1 = SeededGenerator(seed: 7)
        var g2 = SeededGenerator(seed: 7)
        let w = [BonusWindow(key: "k", name: "5h", kind: .session, utilization: 100)]

        var tier2 = tier
        let a = WalletStore.evaluateGrants(windows: w, grantTier: &tier,
                                          availableSets: ["a", "b", "c"], using: &g1)
        let b = WalletStore.evaluateGrants(windows: w, grantTier: &tier2,
                                          availableSets: ["a", "b", "c"], using: &g2)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 1)
    }
}

@MainActor
final class DisenchantTests: XCTestCase {

    private func makeStore() -> WalletStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dust-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
    }

    /// 마지막 한 장은 남는다. 수집한 카드가 컬렉션에서 사라지면 되돌릴 수 없다.
    func testKeepsOneCopy() {
        let s = makeStore()
        s.collect(["sv10-1", "sv10-1", "sv10-1"])
        XCTAssertEqual(s.spareCount("sv10-1"), 2)

        let refund = s.sellSpares(cardID: "sv10-1", tier: .rare, count: 99)
        XCTAssertEqual(s.cardCount("sv10-1"), 1, "한 장은 남아야 한다")
        XCTAssertEqual(refund, CardSale.price(cardID: "sv10-1") * 2)
    }

    /// 한 장뿐이면 갈 수 없다.
    func testSingleCopyCannotBeRecycled() {
        let s = makeStore()
        s.collect(["sv10-1"])
        XCTAssertEqual(s.spareCount("sv10-1"), 0)
        XCTAssertEqual(s.sellSpares(cardID: "sv10-1", tier: .rare, count: 1), 0)
        XCTAssertEqual(s.cardCount("sv10-1"), 1)
    }

    /// 환급은 잔액을 늘리되 누적 사용량은 건드리지 않는다 — 그건 통계다.
    func testRefundRaisesBalanceWithoutTouchingUsage() {
        let s = makeStore()
        s.update(todayTokensByProvider: ["a": 0], todayDate: "2026-08-27", hasUsageData: true)
        s.update(todayTokensByProvider: ["a": 1_000_000], todayDate: "2026-08-27", hasUsageData: true)
        s.collect(["sv10-2", "sv10-2"])

        let before = s.availableTokens
        let refund = s.sellSpares(cardID: "sv10-2", tier: .ultraRare, count: 1)
        XCTAssertEqual(s.availableTokens, before + refund)
        XCTAssertEqual(s.usedSinceInstall, 1_000_000, "사용량 통계는 그대로여야 한다")
    }

    /// 갈고 나면 그 결과가 저장된다.
    func testSurvivesReload() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dust-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("game-state.json")

        let first = WalletStore(fileURL: file)
        first.collect(["sv10-3", "sv10-3"])
        let refund = first.sellSpares(cardID: "sv10-3", tier: .doubleRare, count: 1)

        let reloaded = WalletStore(fileURL: file)
        XCTAssertEqual(reloaded.cardCount("sv10-3"), 1)
        XCTAssertEqual(reloaded.availableTokens, refund)
        XCTAssertEqual(reloaded.state.cardsDisenchanted, 1)
    }
}
