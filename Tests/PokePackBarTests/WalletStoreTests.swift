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

/// 한번에 판매 — 되돌릴 수 없는 동작이라 규칙을 값으로 묶는다.
@MainActor
final class BulkSaleTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bulk-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeStore() -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
    }

    /// 값이 낮은 순으로 카드를 갈라 (싼 카드, 비싼 카드) 를 돌려준다.
    private func split(_ index: CardIndex, _ prices: CardPrices,
                       at won: Int) -> (cheap: CardEntry, dear: CardEntry) {
        let cheap = index.cards.first { prices.krw(prices.price($0.id) ?? 99) < won / 2 }!
        let dear = index.cards.first { prices.krw(prices.price($0.id) ?? 0) > won * 10 }!
        return (cheap, dear)
    }

    /// **마지막 한 장은 절대 팔리지 않는다.** 팔리면 도감 진행이 되돌아가고
    /// 컬렉션에서 카드가 사라지는데 되돌릴 방법이 없다.
    func testTheLastCopyIsNeverSold() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let (cheap, _) = split(index, prices, at: 1_000)

        s.collect([cheap.id])                       // 한 장만
        let targets = WalletStore.bulkSaleTargets([cheap], maxWon: 1_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        XCTAssertTrue(targets.isEmpty, "한 장뿐인 카드가 대상에 들었다")
        XCTAssertEqual(s.sellSpares(targets), .none)
        XCTAssertEqual(s.cardCount(cheap.id), 1)

        s.collect([cheap.id, cheap.id])             // 이제 세 장
        let three = WalletStore.bulkSaleTargets([cheap], maxWon: 1_000,
                                                spares: { s.spareCount($0) }, prices: prices)
        let sale = s.sellSpares(three)
        XCTAssertEqual(sale.copies, 2)
        XCTAssertEqual(s.cardCount(cheap.id), 1, "정리 뒤에도 한 장은 남아야 한다")
    }

    /// 임계값을 넘는 카드는 한 장도 팔리지 않는다.
    func testCardsAboveTheThresholdAreLeftAlone() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let (cheap, dear) = split(index, prices, at: 1_000)

        s.collect([cheap.id, cheap.id, dear.id, dear.id])
        let targets = WalletStore.bulkSaleTargets([cheap, dear], maxWon: 1_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        XCTAssertEqual(targets, [cheap.id])
        s.sellSpares(targets)
        XCTAssertEqual(s.cardCount(cheap.id), 1)
        XCTAssertEqual(s.cardCount(dear.id), 2, "비싼 카드가 팔렸다")
    }

    /// 미리 본 것과 실제로 팔린 것이 같다. 다르면 확인 화면이 거짓말을 한 셈이다.
    func testPreviewMatchesTheSale() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let pool = Array(index.cards.prefix(200))
        for entry in pool { s.collect([entry.id, entry.id, entry.id]) }

        let targets = WalletStore.bulkSaleTargets(pool, maxWon: 5_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        XCTAssertFalse(targets.isEmpty)
        let preview = s.bulkSalePreview(targets)
        let sale = s.sellSpares(targets)
        XCTAssertEqual(preview, sale)

        // 받은 값은 장수마다의 판매가 합계와 같아야 한다(판매 추가금 포함).
        let expected = targets.reduce(0) { $0 + CardSale.price(cardID: $1, perks: s.perks) * 2 }
        XCTAssertEqual(sale.tokens, expected)
        XCTAssertEqual(sale.copies, targets.count * 2)
        XCTAssertEqual(sale.kinds, targets.count)
    }

    /// 잔액에 그만큼 들어오고, 종수는 줄지 않는다.
    func testBalanceRisesAndKindCountHolds() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let pool = Array(index.cards.prefix(60))
        for entry in pool { s.collect([entry.id, entry.id]) }

        let kinds = s.distinctCardCount
        let before = s.availableTokens
        let targets = WalletStore.bulkSaleTargets(pool, maxWon: 10_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        let sale = s.sellSpares(targets)
        XCTAssertEqual(s.availableTokens, before + sale.tokens)
        XCTAssertEqual(s.distinctCardCount, kinds, "종수가 줄었다 — 마지막 장이 팔렸다")
    }

    /// 종류마다 저장하면 164종 정리에 저장이 164번 돈다. 한 번만 써야 한다.
    func testWritesTheSaveFileOnlyOnce() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        let pool = Array(index.cards.prefix(120))
        for entry in pool { s.collect([entry.id, entry.id]) }

        let file = dir.appendingPathComponent("game-state.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let before = attributes[.modificationDate] as? Date ?? .distantPast

        // 쓰기 횟수를 직접 셀 수는 없으므로, 정리 한 번이 한 번의 쓰기로 끝나는지를
        // 파일 크기 변화와 소요 시간으로 본다. 120종을 한 번에 파는 데 1초를 넘기면
        // 종류마다 저장하고 있다는 뜻이다.
        let targets = WalletStore.bulkSaleTargets(pool, maxWon: 10_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        XCTAssertGreaterThan(targets.count, 50, "표본이 너무 작다")
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = s.sellSpares(targets) }
        XCTAssertLessThan(elapsed, .seconds(1), "종류마다 저장하고 있다")
        XCTAssertNotEqual((try FileManager.default
            .attributesOfItem(atPath: file.path)[.modificationDate] as? Date) ?? before, .distantPast)
    }

    /// 시세를 모르는 카드는 잡카드로 본다 — 값을 모르면 남겨 둘 근거도 없다.
    func testUnknownPricesCountAsJunk() throws {
        let s = makeStore()
        let prices = try XCTUnwrap(CardPrices.shared)
        let ghost = CardEntry(id: "no-such-card", name: "?", tier: .common, setID: "no-such")
        s.collect([ghost.id, ghost.id])
        let targets = WalletStore.bulkSaleTargets([ghost], maxWon: 1_000,
                                                  spares: { s.spareCount($0) }, prices: prices)
        XCTAssertEqual(targets, [ghost.id])
    }

    /// 임계값 후보는 실제 시세 분포를 갈라야 한다. 다섯 개가 모두 같은 카드를
    /// 잡으면 고를 이유가 없다.
    func testThresholdsActuallySplitThePool() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.shared)
        func count(_ won: Int) -> Int {
            index.cards.filter { prices.krw(prices.price($0.id) ?? 0.05) <= won }.count
        }
        let counts = BulkSaleView.thresholds.map(count)
        for (lower, upper) in zip(counts, counts.dropFirst()) {
            XCTAssertLessThan(lower, upper, "임계값 후보가 같은 범위를 잡는다: \(counts)")
        }
    }
}

/// 한 번만 주는 보상 — 재화를 넣는 일이라 규칙을 값으로 묶는다.
@MainActor
final class GiftTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gift-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private var file: URL { dir.appendingPathComponent("game-state.json") }
    private func makeStore() -> WalletStore { WalletStore(fileURL: file) }

    private let gift = WalletStore.Gift(id: "test-gift", tokens: 1_000, packsPerSet: 1)

    /// 잔액을 채운다. 사용량 관찰이 유일한 통로다.
    private func fund(_ s: WalletStore, _ tokens: Int) {
        s.update(todayTokensByProvider: ["claude_code": 0], todayDate: "2026-09-01",
                 hasUsageData: true)
        s.update(todayTokensByProvider: ["claude_code": tokens], todayDate: "2026-09-01",
                 hasUsageData: true)
    }

    /// 팩을 사 본 적이 있어야 대상이다.
    private func makeAffected() throws -> (WalletStore, CardIndex) {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        fund(s, 100_000_000)
        s.addPack(setID: try XCTUnwrap(index.setIDs.first))
        XCTAssertTrue(s.consumePack(setID: try XCTUnwrap(index.setIDs.first)))
        return (s, index)
    }

    /// **두 번 불러도 한 번만 들어온다.**
    func testAGiftArrivesOnlyOnce() throws {
        let (s, index) = try makeAffected()
        let before = s.availableTokens

        XCTAssertTrue(s.claim(gift, index: index))
        let afterFirst = s.availableTokens
        XCTAssertEqual(afterFirst, before + gift.tokens)

        XCTAssertFalse(s.claim(gift, index: index), "두 번째 지급이 일어났다")
        XCTAssertEqual(s.availableTokens, afterFirst)
        for setID in index.setIDs {
            XCTAssertEqual(s.packCount(setID: setID), 1, "\(setID): 팩이 두 번 들어왔다")
        }
    }

    /// 앱을 다시 켜도 다시 들어오지 않는다 — 기록이 세이브에 남아야 한다.
    func testTheRecordSurvivesRelaunch() throws {
        let (s, index) = try makeAffected()
        XCTAssertTrue(s.claim(gift, index: index))
        let tokens = s.availableTokens

        let reopened = makeStore()
        XCTAssertFalse(reopened.claim(gift, index: index), "다시 켜니 또 들어왔다")
        XCTAssertEqual(reopened.availableTokens, tokens)
    }

    /// 팩을 사 본 적 없는 세이브는 받지 않는다. **그래도 기록은 남는다** —
    /// 안 남기면 나중에 팩을 하나 사는 순간 대상이 되어 뒤늦게 지급된다.
    func testFreshSavesGetNothingButAreStillMarked() throws {
        let s = makeStore()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        fund(s, 100_000_000)
        let before = s.availableTokens

        XCTAssertFalse(s.claim(gift, index: index))
        XCTAssertEqual(s.availableTokens, before)
        XCTAssertNil(s.lastGift, "안 준 보상을 알렸다")

        // 이제 팩을 사도 뒤늦게 들어오면 안 된다.
        s.addPack(setID: try XCTUnwrap(index.setIDs.first))
        XCTAssertTrue(s.consumePack(setID: try XCTUnwrap(index.setIDs.first)))
        XCTAssertFalse(s.claim(gift, index: index), "뒤늦게 지급됐다")
        XCTAssertEqual(s.availableTokens, before)
    }

    /// 잔액만 오르고 사용량 통계는 그대로다. 통계를 건드리면 화면의 사용량이 거짓이 된다.
    func testUsageStatsAreUntouched() throws {
        let (s, index) = try makeAffected()
        let used = s.usedSinceInstall
        let before = s.availableTokens
        XCTAssertTrue(s.claim(gift, index: index))
        XCTAssertEqual(s.usedSinceInstall, used, "사용량 통계가 늘었다")
        XCTAssertEqual(s.availableTokens, before + gift.tokens)
    }

    /// 세트마다 정확히 지정한 만큼 들어온다.
    func testOnePackPerSet() throws {
        let (s, index) = try makeAffected()
        XCTAssertTrue(s.claim(WalletStore.Gift(id: "two", tokens: 0, packsPerSet: 2),
                              index: index))
        for setID in index.setIDs {
            XCTAssertEqual(s.packCount(setID: setID), 2, "\(setID)")
        }
    }

    /// id 가 다르면 따로 한 번씩 나간다. 다음 보상이 이 칸을 두고 다투지 않아야 한다.
    func testDifferentGiftsAreIndependent() throws {
        let (s, index) = try makeAffected()
        let before = s.availableTokens
        XCTAssertTrue(s.claim(WalletStore.Gift(id: "a", tokens: 100, packsPerSet: 0), index: index))
        XCTAssertTrue(s.claim(WalletStore.Gift(id: "b", tokens: 100, packsPerSet: 0), index: index))
        XCTAssertFalse(s.claim(WalletStore.Gift(id: "a", tokens: 100, packsPerSet: 0), index: index))
        XCTAssertEqual(s.availableTokens, before + 200)
    }

    /// 배포에 실린 사과 보상의 값이 계획과 같은가 — 손이 미끄러져 0 이 하나 더 붙으면
    /// 되돌릴 수 없다.
    func testTheShippedApologyGiftIsWhatWePlanned() {
        XCTAssertEqual(WalletStore.apologyGift.id, "v0.4.1-apology")
        XCTAssertEqual(WalletStore.apologyGift.packsPerSet, 1)
        XCTAssertEqual(MarketEconomy.won(tokens: WalletStore.apologyGift.tokens), 1_000_000,
                       "현금 보상이 100만원이 아니다")
    }
}

/// 카드를 처음 얻은 때를 기록하는가.
@MainActor
final class CardFirstAcquiredTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("first-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeStore() -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"), dexes: [])
    }

    /// 처음 얻은 때만 적는다. 두 번째부터 덮어쓰면 「최초」가 아니게 된다.
    func testKeepsTheFirstTimeOnly() {
        let s = makeStore()
        s.collect(["a-1"])
        let first = try! XCTUnwrap(s.firstAcquired("a-1"))
        s.collect(["a-1", "a-1"])
        XCTAssertEqual(s.firstAcquired("a-1"), first, "다시 얻었다고 날짜가 바뀌면 안 된다")
        XCTAssertEqual(s.cardCount("a-1"), 3)
    }

    /// 아예 가진 적 없는 카드는 날짜가 없다.
    func testUnknownWhenNeverOwned() {
        let s = makeStore()
        XCTAssertNil(s.firstAcquired("a-1"))
        XCTAssertEqual(s.firstAcquiredStamp("a-1"), 0, "정렬에서 맨 뒤로 가야 한다")
    }

    /// **기록이 생기기 전에 모은 카드는 세이브를 읽을 때 그날 날짜로 채운다.**
    ///
    /// 안 채우면 이미 수백 장을 모은 세이브에서 날짜도 「최근 획득순」도 빈 채로 남는다.
    func testBackfillsCardsSavedBeforeTheRecordExisted() throws {
        // 날짜 칸이 없던 시절의 세이브를 흉내 낸다.
        let legacy: [String: Any] = ["cards": ["a-1": 2, "a-2": 1], "packs": [:]]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let url = dir.appendingPathComponent("game-state.json")
        try data.write(to: url)

        let s = makeStore()
        let stamp = s.firstAcquiredStamp("a-1")
        XCTAssertGreaterThan(stamp, 0, "옛 카드에 날짜가 안 채워졌다")
        XCTAssertEqual(s.firstAcquiredStamp("a-2"), stamp, "같은 때로 채워야 한다")

        // 채운 값은 저장돼야 한다 — 다시 켤 때마다 오늘로 밀리면 「최초」가 아니다.
        XCTAssertEqual(makeStore().firstAcquiredStamp("a-1"), stamp)

        // 채워 넣은 카드보다 새로 얻는 카드가 뒤다.
        s.collect(["a-3"])
        XCTAssertGreaterThanOrEqual(s.firstAcquiredStamp("a-3"), stamp)
    }

    /// 다시 켜도 남아 있어야 한다 — 세이브에 들어가는 값이다.
    func testSurvivesRestart() {
        let s = makeStore()
        s.collect(["a-1"])
        let stamp = s.firstAcquiredStamp("a-1")
        XCTAssertGreaterThan(stamp, 0)
        XCTAssertEqual(makeStore().firstAcquiredStamp("a-1"), stamp)
    }

    /// 판 카드도 기록은 남긴다. 다시 얻어도 처음 얻은 날은 그날이다.
    func testSellingKeepsTheDate() {
        let s = makeStore()
        s.collect(["a-1", "a-1"])
        let stamp = s.firstAcquiredStamp("a-1")
        s.sellSpares(cardID: "a-1", tier: .rare, count: 1)
        XCTAssertEqual(s.firstAcquiredStamp("a-1"), stamp)
    }
}

/// 판올림 기념 사료 — 딱 100만원이고, 한 번만 들어온다.
@MainActor
final class PatchGiftTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patch-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func played() -> WalletStore {
        let s = WalletStore(fileURL: dir.appendingPathComponent("game-state.json"), dexes: [])
        s.addPack(setID: "base1", count: 1)
        s.consumePack(setID: "base1")          // 팩을 사 본 세이브로 만든다
        return s
    }

    /// **정확히 100만원이어야 한다.** 어정쩡한 액수가 뜨면 기념이 아니라 실수처럼 보인다.
    func testGrantsExactlyOneMillionWon() throws {
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        XCTAssertEqual(MarketEconomy.won(tokens: WalletStore.patchGift.tokens, prices: prices),
                       1_000_000)
    }

    /// 팩은 주지 않는다 — 이번 보상은 현금뿐이다.
    func testGivesNoPacks() {
        let s = played()
        let before = s.totalPackCount
        s.claim(WalletStore.patchGift, index: nil)
        XCTAssertEqual(s.totalPackCount, before)
    }

    /// 두 번 불러도 한 번만 들어온다.
    func testGrantsOnlyOnce() {
        let s = played()
        let before = s.availableTokens
        s.claim(WalletStore.patchGift, index: nil)
        let after = s.availableTokens
        XCTAssertEqual(after - before, WalletStore.patchGift.tokens)
        s.claim(WalletStore.patchGift, index: nil)
        XCTAssertEqual(s.availableTokens, after, "두 번째 호출에서 또 들어왔다")
    }

    /// 사죄 사료와 별개다 — id 가 다르면 각자 한 번씩 나간다.
    func testIsSeparateFromTheApologyGift() {
        let s = played()
        s.claim(WalletStore.apologyGift, index: nil)
        let after = s.availableTokens
        XCTAssertTrue(s.claim(WalletStore.patchGift, index: nil))
        XCTAssertEqual(s.availableTokens - after, WalletStore.patchGift.tokens)
    }

    /// 알림 문구가 기념 쪽으로 나와야 한다. 사과 문구가 뜨면 무슨 일인지 알 수 없다.
    func testTellsTheUserItIsACelebration() {
        XCTAssertEqual(WalletStore.patchGift.kind, .celebration)
        let l = L(.ko)
        XCTAssertNotEqual(l.giftTitle(.celebration), l.giftTitle(.apology))
        XCTAssertFalse(l.giftBody(.celebration, packs: 0, money: "1,000,000원").contains("팩"),
                       "팩을 안 주는데 팩 이야기를 한다")
    }
}
