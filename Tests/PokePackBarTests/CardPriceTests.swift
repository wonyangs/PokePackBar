import XCTest
@testable import PokePackBar

/// 번들에 실린 시세 스냅샷.
///
/// 카드값이 게임 경제의 뿌리가 되므로, 빠진 카드나 0원짜리 카드가 조용히 섞이면
/// 그 카드만 분해값이 0 인 상태로 나간다.
final class CardPriceTests: XCTestCase {

    private static let prices = CardPrices.loadBundled()

    func testBundleCarriesPrices() throws {
        let prices = try XCTUnwrap(Self.prices, "card-prices.json 이 번들에 없다")
        XCTAssertFalse(prices.asOf.isEmpty, "기준일이 비어 있으면 언제 값인지 알 수 없다")
        XCTAssertEqual(prices.currency, "USD")
    }

    /// 한 장도 빠지면 안 된다. 빠진 카드는 화면에서 시세 줄이 통째로 사라진다.
    func testEveryCardHasAPrice() throws {
        let prices = try XCTUnwrap(Self.prices)
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let missing = index.cards.filter { prices.price($0.id) == nil }
        XCTAssertTrue(missing.isEmpty,
                      "시세가 없는 카드 \(missing.count)장: "
                      + missing.prefix(5).map(\.id).joined(separator: ", "))
    }

    /// 0원짜리는 두지 않는다. 분해값을 시세에서 뽑기 시작하면 갈 수도 없는 카드가 된다.
    func testNoCardIsFree() throws {
        let prices = try XCTUnwrap(Self.prices)
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for entry in index.cards {
            XCTAssertGreaterThan(prices.price(entry.id) ?? 0, 0, "\(entry.id) 시세가 0 이다")
        }
    }

    func testHoldingsMultiplyByCount() throws {
        let prices = try XCTUnwrap(Self.prices)
        let id = try XCTUnwrap(CardIndex.loadBundled()?.cards.first?.id)
        let unit = try XCTUnwrap(prices.price(id))
        XCTAssertEqual(prices.total(id, count: 3) ?? 0, unit * 3, accuracy: 0.0001)
        XCTAssertNil(prices.total(id, count: 0), "갖고 있지 않으면 보유액이 없다")
    }

    /// 큰 값에서는 소수점이 잡음이고, 작은 값에서는 두 자리가 의미를 갖는다.
    func testFormattingDropsCentsOnLargeValues() throws {
        let prices = try XCTUnwrap(Self.prices)
        XCTAssertEqual(prices.formatted(1465.99), "$1,466")
        XCTAssertEqual(prices.formatted(868.56), "$869")
        XCTAssertEqual(prices.formatted(99.99), "$99.99", "100 아래에서는 센트가 의미를 갖는다")
        XCTAssertEqual(prices.formatted(0.3), "$0.30")
    }

    /// 주 단위가 원이고 달러는 괄호에 남는다.
    func testWonLeadsAndDollarFollows() throws {
        let prices = try XCTUnwrap(Self.prices)
        XCTAssertGreaterThan(prices.krwPerUSD, 100, "환율이 비어 있으면 원화 칸이 사라진다")

        let line = prices.formattedWithKRW(868.56, language: .ko)
        XCTAssertTrue(line.hasSuffix("($869)"), line)
        XCTAssertTrue(line.hasPrefix("1,"), "원화가 앞에 와야 한다: \(line)")
        XCTAssertTrue(line.contains("원 ("), line)
    }

    /// 끝자리를 끊는 규칙. 천원 위는 천 단위 반올림, 그 아래는 100원 절삭.
    func testWonRounding() {
        XCTAssertEqual(WonFormatter.rounded(36_412), 36_000)
        XCTAssertEqual(WonFormatter.rounded(36_500), 37_000, "반올림이다")
        XCTAssertEqual(WonFormatter.rounded(1_499), 1_000)
        XCTAssertEqual(WonFormatter.rounded(999), 900, "천원 아래는 100원 단위로 자른다")
        XCTAssertEqual(WonFormatter.rounded(413), 400)
        XCTAssertEqual(WonFormatter.rounded(50), 0)
        XCTAssertEqual(WonFormatter.rounded(0), 0)
    }

    /// 세 자리 쉼표로 읽는다. 끝자리는 이미 끊겨 있다.
    func testWonReadsInGroupedDigits() {
        let ko = Locale(identifier: "ko_KR")
        XCTAssertEqual(WonFormatter.money(36_412, language: .ko, locale: ko), "36,000원")
        XCTAssertEqual(WonFormatter.money(1_195_741, language: .ko, locale: ko), "1,196,000원")
        XCTAssertEqual(WonFormatter.money(413, language: .ko, locale: ko), "400원")
        XCTAssertEqual(WonFormatter.money(100_000_000, language: .ko, locale: ko), "100,000,000원")
    }

    /// 단위 기호는 언어를 따른다.
    func testCurrencyMarkFollowsLanguage() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(WonFormatter.money(36_412, language: .en, locale: us), "₩36,000")
        XCTAssertEqual(WonFormatter.money(36_412, language: .ja, locale: us), "36,000円")
    }

    /// 등급만으로 값을 매기던 표가 시장과 어긋난다는 것 — 이 격차가 개편의 근거다.
    /// 뒤집힘이 사라졌다면 시세가 크게 바뀐 것이니 경제 설계를 다시 봐야 한다.
    func testTierOrderDoesNotMatchTheMarket() throws {
        let prices = try XCTUnwrap(Self.prices)
        let index = try XCTUnwrap(CardIndex.loadBundled())
        func median(_ tier: CardTier) -> Double {
            let values = index.cards.filter { $0.tier == tier }
                .compactMap { prices.price($0.id) }.sorted()
            return values.isEmpty ? 0 : values[values.count / 2]
        }
        XCTAssertGreaterThan(median(.specialArtRare), median(.ultraRare),
                             "SAR 이 UR 보다 싸졌다면 등급표를 다시 봐야 한다")
        XCTAssertGreaterThan(median(.artRare), median(.superRare))
    }

    /// 판매가는 화면에 적힌 카드값과 **같아야** 한다.
    ///
    /// 카드 상세는 "이 카드 12,000원" 이라고 적어 둔다. 팔 때 그보다 적게 주면 적어 둔 값이
    /// 무엇을 뜻하는지 알 수 없게 된다. 토큰을 거쳐 돌아오는 길에 배율이 끼어들지 않았는지
    /// 여기서 잡는다.
    func testSalePriceEqualsTheCardValueOnScreen() throws {
        let prices = try XCTUnwrap(Self.prices)
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for entry in index.cards.prefix(200) {
            guard let usd = prices.price(entry.id) else { continue }
            let shown = prices.krw(usd)
            let paid = MarketEconomy.won(tokens: CardSale.price(cardID: entry.id, prices: prices),
                                         prices: prices)
            // 토큰이 정수라 1원 안쪽으로 어긋날 수 있다. 그 이상은 배율이 낀 것이다.
            XCTAssertEqual(Double(paid), Double(shown), accuracy: 1,
                           "\(entry.id): 적힌 값 \(shown)원, 판매가 \(paid)원")
        }
    }

    /// 도감 추가금은 그 위에 얹힌다 — 시세보다 적게 주는 일은 없다.
    func testSaleBonusOnlyAddsOnTop() throws {
        let prices = try XCTUnwrap(Self.prices)
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let card = try XCTUnwrap(index.cards.first { prices.price($0.id) ?? 0 > 1 })
        let plain = CardSale.price(cardID: card.id, prices: prices)
        let boosted = CardSale.price(cardID: card.id, prices: prices,
                                     perks: DexPerks(dustBonus: DexPerks.caps.dustBonus))
        XCTAssertGreaterThan(boosted, plain)
    }
}
