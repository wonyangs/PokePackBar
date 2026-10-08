import XCTest
@testable import PokePackBar

@MainActor
final class OnlineAuditFixtureTests: XCTestCase {
    func testMarketFixtureUsesRemainingSpareAfterCounterOffer() {
        let stock: [[String: Any]] = [
            ["printing": "original", "available": 0],
            ["printing": "remaining", "available": 1],
        ]
        XCTAssertEqual(OnlineGameAudit.fixtureListingPrinting(stock: stock, preferred: "original"), "remaining")
        XCTAssertEqual(OnlineGameAudit.fixtureListingPrinting(stock: stock, preferred: "remaining"), "remaining")
        XCTAssertNil(OnlineGameAudit.fixtureListingPrinting(stock: [["printing": "original", "available": 0]], preferred: "original"))
    }
}
