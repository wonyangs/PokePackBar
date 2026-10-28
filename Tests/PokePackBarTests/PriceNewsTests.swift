import Foundation
import XCTest
@testable import PokePackBar

/// 오늘의 시세와 시세 기록: 서버 응답을 어떻게 읽고, 언제 다시 묻고, 무엇을 알리는가.
@MainActor
final class PriceNewsTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "ppb-price-news-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private final class Counter { var value = 0 }

    private func move(_ kind: String, _ item: String, _ before: Double, _ after: Double,
                      count: Int? = nil) -> [String: Any] {
        var move: [String: Any] = ["kind": kind, "item": item, "before": before, "after": after]
        if let count { move["count"] = count }
        return move
    }

    private func report(day: String?, owned: [[String: Any]] = []) -> [String: Any] {
        ["day": day ?? NSNull(), "since": NSNull(), "changed": owned.count,
         "risers": [move("printing", "base1-4#holo", 300, 360)],
         "fallers": [], "packs": [move("pack", "base1", 900, 880)], "owned": owned]
    }

    /// 서버 흉내. 부를 때마다 `reports` 의 다음 응답을 준다.
    private func server(_ reports: [[String: Any]], requests: Counter) -> (String) async throws -> Data {
        { path in
            XCTAssertEqual(path, PriceHistoryRequest.movers)
            let reply = reports[min(requests.value, reports.count - 1)]
            requests.value += 1
            return try JSONSerialization.data(withJSONObject: reply)
        }
    }

    func testMovesNameTheCardAndFinishTheAppShows() throws {
        let data = try JSONSerialization.data(withJSONObject: report(day: "2026-10-22", owned: [
            move("printing", "sv8-238#holo", 10, 12, count: 2),
            move("card", "base1-55", 4, 3, count: 1),
            move("printing", "sv8-1#futureFinish", 1, 2, count: 1),
        ]))
        let decoded = try JSONDecoder().decode(PriceReport.self, from: data)
        XCTAssertEqual(decoded.day, "2026-10-22")
        XCTAssertEqual(decoded.owned.map(\.cardID), ["sv8-238", "base1-55", "sv8-1"])
        XCTAssertEqual(decoded.owned.map(\.finish), [.holo, nil, nil],
                       "모르는 판형이 와도 카드는 맞게 가린다")
        XCTAssertEqual(decoded.owned[0].valueChange, 4, accuracy: 1e-9)
        XCTAssertEqual(decoded.owned[0].rate, 0.2, accuracy: 1e-9)
        XCTAssertEqual(decoded.packs.first?.cardID, "base1")
    }

    /// 시세가 그대로면 다시 묻지 않는다. 새 시세가 들어오거나 오래되면 다시 묻는다.
    func testRefreshAsksAgainOnlyForNewPricesOrStaleNews() async {
        let news = PriceNews(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let fetch = server([report(day: "2026-10-22")], requests: requests)
        await news.refresh(version: "v1", fetch: fetch)
        await news.refresh(version: "v1", fetch: fetch)
        XCTAssertEqual(requests.value, 1)
        XCTAssertEqual(news.report?.risers.first?.item, "base1-4#holo")
        await news.refresh(version: "v2", fetch: fetch)
        XCTAssertEqual(requests.value, 2)
        await news.refresh(version: "v2", maxAge: 0, fetch: fetch)
        XCTAssertEqual(requests.value, 3, "통계 탭을 열면 같은 시세여도 내 카드를 다시 본다")
    }

    /// 이 기능을 모르는 서버에는 한 번만 묻는다. 다른 실패는 다음에 다시 묻는다.
    func testOldServerIsAskedOnce() async {
        let news = PriceNews(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let missing: (String) async throws -> Data = { _ in
            requests.value += 1
            throw RemoteGameSession.Failure(message: "not found", status: 404)
        }
        await news.refresh(version: "v1", fetch: missing)
        await news.refresh(version: "v2", fetch: missing)
        XCTAssertEqual(requests.value, 1)
        XCTAssertTrue(news.unsupported)
        XCTAssertFalse(news.failed)

        let other = PriceNews(storageKey: "b", defaults: defaults)
        let down: (String) async throws -> Data = { _ in
            requests.value += 1
            throw RemoteGameSession.Failure(message: "down", status: 503)
        }
        await other.refresh(version: "v1", fetch: down)
        await other.refresh(version: "v1", fetch: down)
        XCTAssertEqual(requests.value, 3)
        XCTAssertTrue(other.failed)
    }

    /// 처음 본 날은 기준만 잡는다. 그 뒤 새 날에 내 카드가 크게 올랐으면 한 번 알린다.
    func testOwnedRisesAreAnnouncedOncePerNewDay() async {
        let news = PriceNews(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let rise = move("printing", "sv8-238#holo", 10, 12, count: 2)
        let fetch = server([
            report(day: "2026-10-21", owned: [rise]),
            report(day: "2026-10-22", owned: [rise, move("card", "base1-55", 4, 5, count: 1),
                                              move("printing", "sv8-2#normal", 1, 1.2, count: 1)]),
        ], requests: requests)
        let body: (PriceMove, Int) -> String = { "\($0.cardID) \(PriceChangeFormat.percent($0.rate)) +\($1)" }

        await news.refresh(version: "v1", fetch: fetch)
        XCTAssertNil(news.announcement(enabled: true, title: "t", body: body), "지난 소식은 알리지 않는다")
        XCTAssertNil(news.announcement(enabled: true, title: "t", body: body))

        await news.refresh(version: "v2", fetch: fetch)
        let sent = news.announcement(enabled: true, title: "t", body: body)
        // 20센트 오른 카드는 알릴 만한 변동이 아니다.
        XCTAssertEqual(sent?.body, "sv8-238 +20% +1")
        XCTAssertEqual(sent?.kind, PriceNews.alertKind)
        XCTAssertEqual(sent?.identifier, "ppb-price-2026-10-22")
        XCTAssertNil(news.announcement(enabled: true, title: "t", body: body), "같은 날은 한 번만")

        // 다시 켜도 같은 계정은 같은 날을 또 알리지 않는다.
        let again = PriceNews(storageKey: "a", defaults: defaults)
        await again.refresh(version: "v2", fetch: fetch)
        XCTAssertNil(again.announcement(enabled: true, title: "t", body: body))
    }

    /// 알림을 꺼 두었어도 그날은 본 것으로 친다. 나중에 켰을 때 지난 소식이 오지 않게 한다.
    func testDisabledNotificationsStillMarkTheDay() async {
        let news = PriceNews(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let rise = move("printing", "sv8-238#holo", 10, 12, count: 1)
        let fetch = server([report(day: "2026-10-21"), report(day: "2026-10-22", owned: [rise])],
                           requests: requests)
        await news.refresh(version: "v1", fetch: fetch)
        _ = news.announcement(enabled: false, title: "t") { _, _ in "" }
        await news.refresh(version: "v2", fetch: fetch)
        XCTAssertNil(news.announcement(enabled: false, title: "t") { _, _ in "" })
        XCTAssertNil(news.announcement(enabled: true, title: "t") { _, _ in "" })
    }

    /// 아직 기록이 없는 서버의 응답도 읽는다. 알릴 날이 없으니 기준도 잡지 않는다.
    func testEmptyHistoryHasNoDay() async {
        let news = PriceNews(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let empty: [String: Any] = ["day": NSNull(), "since": NSNull(), "changed": 0, "risers": [],
                                    "fallers": [], "packs": [], "owned": []]
        await news.refresh(version: "v1", fetch: server([empty], requests: requests))
        XCTAssertNotNil(news.report)
        XCTAssertNil(news.report?.day)
        XCTAssertNil(news.announcement(enabled: true, title: "t") { _, _ in "" })
        XCTAssertNil(news.announcedDay)
    }

    func testHistoryPathEscapesThePrintingKey() {
        XCTAssertEqual(PriceHistoryRequest.path(kind: "printing", item: "base1-4#holo", range: .quarter),
                       "v1/prices/history?kind=printing&item=base1%2D4%23holo&days=90")
        XCTAssertEqual(PriceHistoryRequest.path(kind: "pack", item: "sv8", range: .all),
                       "v1/prices/history?kind=pack&item=sv8&days=0")
    }

    /// 카드 상세가 보여 주는 값과 같은 기록을 고른다. 판형 시세가 없으면 카드 대표값이다.
    func testHistoryFollowsTheValueTheDetailShows() throws {
        let prices = try XCTUnwrap(CardPrices.decode(Data("""
        {"asOf":"2026-10-01","currency":"USD","krwPerUsd":1350,
         "prices":{"a-1":5,"b-1":3},"printingPrices":{"a-1#holo":5}}
        """.utf8)))
        XCTAssertTrue(PriceHistoryRequest.card("a-1", finish: .holo, prices: prices) == ("printing", "a-1#holo"))
        XCTAssertTrue(PriceHistoryRequest.card("a-1", finish: .reverseHolo, prices: prices) == ("card", "a-1"))
        XCTAssertTrue(PriceHistoryRequest.card("b-1", finish: nil, prices: prices) == ("card", "b-1"))
    }

    /// 값이 바뀐 날만 점이 온다. 마지막 값은 최근 기록일까지 잇고, 그사이 날의 값은 앞 점의 값이다.
    func testSeriesCarriesTheLastValueToTheLatestDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let series = PriceSeries(kind: "printing", item: "a#holo", latest_day: "2026-10-22",
                                 points: [.init(day: "2026-10-01", usd: 10), .init(day: "2026-10-10", usd: 12)])
        let samples = series.samples(calendar: calendar)
        XCTAssertEqual(samples.map(\.usd), [10, 12, 12])
        XCTAssertEqual(samples.map { calendar.component(.day, from: $0.date) }, [1, 10, 22],
                       "기록일은 이 기기의 그날로 읽힌다")
        let middle = try XCTUnwrap(PriceHistoryRequest.day("2026-10-05", calendar: calendar))
        XCTAssertEqual(PriceSeries.value(at: middle, in: samples)?.usd, 10)
        let today = PriceSeries(kind: "card", item: "a", latest_day: "2026-10-22",
                                points: [.init(day: "2026-10-22", usd: 3)])
        XCTAssertEqual(today.samples(calendar: calendar).count, 1)
    }

    func testChangesAlwaysCarryTheirSign() {
        XCTAssertEqual(PriceChangeFormat.percent(0.2), "+20%")
        XCTAssertEqual(PriceChangeFormat.percent(-0.034), "\u{2212}3.4%")
        XCTAssertEqual(PriceChangeFormat.percent(0.0001), "0%")
        XCTAssertEqual(PriceChangeFormat.won(0, language: .ko), WonFormatter.money(0, language: .ko))
        XCTAssertTrue(PriceChangeFormat.won(-2_700, language: .ko).hasPrefix("\u{2212}"))
    }

    /// 새 문구는 여섯 언어가 모두 채워져 있고 서로 다르다(한국어를 그대로 두지 않았다).
    func testPriceCopyIsTranslated() {
        let strings: (L) -> [String] = { l in
            [l.priceNewsHeader, l.priceNewsMine, l.priceNewsRisers, l.priceNewsFallers, l.priceNewsPacks,
             l.priceNewsGathering, l.priceNewsQuiet, l.priceNewsUnavailable, l.priceRiseTitle,
             l.priceHistory, l.priceHistoryOneDay, l.priceHistoryFailed, l.priceHistoryEmpty,
             l.priceRiseBody("X", "+5%", more: 2), l.priceChangeOver("+5%", .month)]
        }
        let korean = strings(L(.ko))
        for language in AppLanguage.allCases where language != .ko {
            for (index, text) in strings(L(language)).enumerated() {
                XCTAssertFalse(text.isEmpty)
                XCTAssertNotEqual(text, korean[index], "\(language): \(text)")
            }
        }
    }
}
