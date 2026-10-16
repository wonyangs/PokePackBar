import Foundation
import XCTest
@testable import PokePackBar

/// 교환에 얹는 돈과 마켓 가격 제안의 화면 문장.
@MainActor
final class MarketOfferTests: XCTestCase {

    /// 교환 시세 비교는 얹은 돈까지 더해 양쪽을 견준다.
    func testValueBalanceCountsMoney() {
        let text = OnlineText.valueBalance(give: [:], get: [:], giveWon: 30_000, getWon: 0)
        let expected = OnlineText.l.valueBalance(give: OnlineText.wonText(30_000), get: OnlineText.wonText(0),
                                                 difference: -30_000, gap: OnlineText.wonText(30_000))
        XCTAssertEqual(text, expected)
    }

    /// 제안 알림은 상대 이름, 카드, 장당 가격을 넣어 말한다. 이름이 없으면 짧은 문장으로 돌아간다.
    func testOfferNotificationsNameTheCardAndPrice() throws {
        let key = "base1-4#holo"
        try XCTSkipIf(CardIndex.shared?.card("base1-4") == nil, "카드 목록 없음")
        let printing = OnlineText.printing(key)
        let card = "\(printing.name) (\(printing.finish))"
        let price = OnlineText.won(tokens: 120_000)
        XCTAssertEqual(OnlineText.notificationText(kind: "offer_received", nickname: "지우", printing: key, unitTokens: 120_000),
                       OnlineText.l.noteOfferReceivedCard("지우", card: card, price: price))
        XCTAssertEqual(OnlineText.notificationText(kind: "offer_accepted", nickname: "지우", printing: key, unitTokens: 120_000),
                       OnlineText.l.noteOfferAcceptedCard("지우", card: card, price: price))
        XCTAssertEqual(OnlineText.notificationText(kind: "offer_expired", printing: key, unitTokens: 120_000),
                       OnlineText.l.noteOfferExpiredCard(card))
        XCTAssertEqual(OnlineText.notificationText(kind: "offer_rejected"), OnlineText.l.noteOfferRejected)
    }

    /// 제안 알림은 마켓을 연다. 수락은 교환의 「교환 완료」가 아니라 「수락됨」으로 적는다.
    func testOffersOpenTheMarketAndHaveTheirOwnAcceptedLabel() {
        for kind in ["offer_received", "offer_accepted", "offer_rejected", "offer_expired"] {
            XCTAssertEqual(OnlineText.destination(kind), .market, kind)
        }
        XCTAssertEqual(OnlineText.offerStatus("accepted").text, OnlineText.l.offerAccepted)
        XCTAssertEqual(OnlineText.offerStatus("pending").text, OnlineText.l.tradePending)
    }
}
