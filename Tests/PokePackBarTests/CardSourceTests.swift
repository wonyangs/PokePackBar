import Foundation
import XCTest
@testable import PokePackBar

/// 카드 상세와 마켓 판매 글이 보여 주는 출처 팩, 뽑힐 확률, 마켓 판매 글 요약, 위시리스트.
@MainActor
final class CardSourceTests: XCTestCase {

    /// 확률은 「약 N팩에 1장」으로 읽는다. 팩마다 한 장 넘게 나오면 그렇게 적고, 안 나오면 적지 않는다.
    func testChanceReadsAsPacksPerCard() {
        let l = L(.ko)
        func source(_ rate: Double) -> CardSource {
            CardSource(setID: "base1", setName: "Base", number: nil, perPack: rate)
        }
        XCTAssertEqual(source(1.0 / 120).chanceText(l), l.pullOneIn("120"))
        XCTAssertEqual(source(1.0 / 3300).packsPerCard, 3300)
        XCTAssertEqual(source(0.8).chanceText(l), l.pullOneIn("1"))
        XCTAssertEqual(source(1.4).chanceText(l), l.pullEveryPack)
        XCTAssertNil(source(0).chanceText(l))
    }

    /// Trainer Gallery 같은 별도 번호 서브셋 카드는 실제로 뽑히는 부모 팩을 출처로 적고, 그 팩에서 나온다.
    func testSubsetCardsComeFromTheirParentPack() throws {
        let index = try XCTUnwrap(CardIndex.shared)
        let id = try XCTUnwrap(index.cards(inSet: "swsh9").first { $0.hasPrefix("swsh9tg-") })
        let source = try XCTUnwrap(CardSource.of(cardID: id, index: index, perks: .none))
        XCTAssertEqual(source.setID, "swsh9")
        XCTAssertGreaterThan(source.perPack, 0)
    }

    /// 판매 글 요약은 그 카드의 글만, 내가 살 수 있는 것만 센다.
    func testListingSummaryCountsOnlyWhatICanBuy() {
        let reply: [String: Any] = [
            "items": [
                ["printing": "sv1-1#holo", "unit_tokens": 900],
                ["printing": "sv1-1#reverse", "unit_tokens": 700],
                ["printing": "sv1-10#holo", "unit_tokens": 100],
                ["printing": "sv1-1#holo", "unit_tokens": 50, "mine": true],
                ["printing": "sv1-1#normal", "unit_tokens": 60, "rotation": true, "bought": true],
            ],
            "next_offset": NSNull(),
        ]
        XCTAssertEqual(CardMarketSummary.from(reply, cardID: "sv1-1"),
                       CardMarketSummary(count: 2, more: false, lowestTokens: 700))
        var paged = reply
        paged["next_offset"] = 100
        XCTAssertTrue(CardMarketSummary.from(paged, cardID: "sv1-1").more)
        XCTAssertEqual(CardMarketSummary.from(["items": []], cardID: "sv1-1"),
                       CardMarketSummary(count: 0, more: false, lowestTokens: nil))
        // 「#」까지 붙여 찾아야 sv1-10 같은 다른 카드가 서버 검색에 걸리지 않는다.
        XCTAssertTrue(CardMarketSummary.query(cardID: "sv1-1").contains("q=sv1%2D1%23&"))
    }

    /// 위시리스트는 판형을 가리지 않고 넣고, 뺄 때는 그 카드의 항목을 모두 뺀다. 다른 카드는 그대로다.
    func testWishlistToggleKeepsOtherWishes() {
        let reply: [String: Any] = ["profile": ["wishlist": [
            ["card_id": "base1-4", "finish": "holo", "target": 2, "owned": 0, "missing": 2],
        ]]]
        let wishes = CardWishlist.wishes(fromProfile: reply)
        XCTAssertEqual(wishes.count, 1)
        XCTAssertNil(wishes[0]["owned"], "서버가 덧붙인 보유 수는 다시 보내지 않는다")
        let added = CardWishlist.toggled(wishes, cardID: "sv1-1")
        XCTAssertEqual(added.count, 2)
        XCTAssertTrue(added[1]["finish"] is NSNull)
        XCTAssertEqual(added[1].int("target"), 1)
        XCTAssertTrue(CardWishlist.contains(added, cardID: "sv1-1"))
        let removed = CardWishlist.toggled(added, cardID: "base1-4")
        XCTAssertEqual(removed.map { $0.string("card_id") }, ["sv1-1"])
    }
}
