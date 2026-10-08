import XCTest
@testable import PokePackBar

/// Separately numbered galleries and shiny vaults are physically inserted in
/// their parent expansion's booster. They must not become imaginary standalone
/// packs, and every imported card needs a usable market value.
final class CardSubsetTests: XCTestCase {
    private let subsets: [(source: String, parent: String, count: Int)] = [
        ("sma", "sm115", 94),
        ("swsh45sv", "swsh45", 122),
        ("cel25c", "cel25", 25),
        ("swsh9tg", "swsh9", 30),
        ("swsh10tg", "swsh10", 30),
        ("swsh11tg", "swsh11", 30),
        ("swsh12tg", "swsh12", 30),
        ("swsh12pt5gg", "swsh12pt5", 70),
    ]

    func testSpecialSubsetsJoinParentPackPoolsWithoutCreatingPacks() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())

        for subset in subsets {
            let cards = index.cards.filter { $0.id.hasPrefix(subset.source + "-") }
            XCTAssertEqual(cards.count, subset.count, subset.source)
            XCTAssertTrue(cards.allSatisfy { $0.setID == subset.parent }, subset.source)
            XCTAssertNil(index.set(subset.source), "\(subset.source) must not become a standalone pack")

            let parentPool = Set(index.cards(inSet: subset.parent))
            XCTAssertTrue(cards.allSatisfy { parentPool.contains($0.id) }, subset.source)
        }
    }

    func testParentCollectionCountsIncludeTheirSubsets() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let expectedTotals = [
            "sm115": 163,
            "swsh45": 195,
            "cel25": 50,
            "swsh9": 216,
            "swsh10": 246,
            "swsh11": 247,
            "swsh12": 245,
            "swsh12pt5": 230,
        ]

        for (setID, expected) in expectedTotals {
            XCTAssertEqual(index.set(setID)?.cardCount, expected, setID)
            XCTAssertEqual(index.cards(inSet: setID).count, expected, setID)
        }
    }

    func testEveryImportedSubsetCardHasAPrice() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        let sourcePrefixes = Set(subsets.map(\.source))
        let imported = index.cards.filter { card in
            guard let dash = card.id.firstIndex(of: "-") else { return false }
            return sourcePrefixes.contains(String(card.id[..<dash]))
        }

        XCTAssertEqual(imported.count, subsets.reduce(0) { $0 + $1.count })
        XCTAssertTrue(imported.allSatisfy { (prices.price($0.id) ?? 0) > 0 })
    }

    func testClassicCollectionRetainsItsDistinctFinish() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let card = try XCTUnwrap(index.card("cel25c-4_A"))
        XCTAssertEqual(card.setID, "cel25")
        XCTAssertEqual(card.rarity, "Classic Collection")
        XCTAssertEqual(
            CardFinishResolver.resolve(
                setID: card.setID,
                originalRarity: card.rarity,
                tier: card.tier
            ).finish,
            .celebrationsClassic
        )
    }

    func testSubsetPullRatesComeFromTheirPhysicalReplacementPositions() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())

        func perPack(_ setID: String, _ tier: CardTier) -> Double {
            let perCard = PackOpening.packOdds(setID: setID, index: index)
                .first { $0.tier == tier }?.probability ?? 0
            return perCard * Double(PackPricing.cardCount(setID: setID, index: index))
        }

        XCTAssertEqual(perPack("sm115", .shiny), 0.212, accuracy: 0.0001)
        XCTAssertEqual(perPack("sm115", .shinyUltra), 0.1222, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh45", .shiny), 0.2273, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh9", .characterRare), 0.1806, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh10", .characterRare), 0.1258, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh11", .characterRare), 0.1231, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh12", .characterRare), 0.1223, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh12pt5", .artRare), 0.224, accuracy: 0.0001)
        XCTAssertEqual(perPack("swsh12pt5", .specialArtRare), 0.128, accuracy: 0.0001)
        XCTAssertEqual(perPack("cel25", .characterRare), 0.40, accuracy: 0.0001)
    }

    func testCelebrationsHasOneClassicEligiblePosition() {
        let recipe = PackRecipe.forSet("cel25", era: .swordShield)
        XCTAssertEqual(recipe.contents.gameCardCount, 4)
        XCTAssertEqual(recipe.slots, [
            PackRecipeSlot(kind: .celebrationsHolo, count: 2),
            PackRecipeSlot(kind: .classicCollection, count: 1),
            PackRecipeSlot(kind: .celebrationsRare, count: 1),
        ])
    }

    func testSubsetMetadataResolvesItsActualFoilFamily() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())

        func finish(_ cardID: String) throws -> CardFinish {
            let card = try XCTUnwrap(index.card(cardID))
            // 비밀 레어는 카드 번호로 판형을 가른다(금색 VSTAR 와 금색 아이템 등). 앱처럼 ID 를 넘긴다.
            return CardFinishResolver.resolve(
                cardID: cardID,
                setID: card.setID,
                originalRarity: card.rarity,
                tier: card.tier
            ).finish
        }

        XCTAssertEqual(try finish("swsh45sv-SV107"), .shinyFullArt)
        XCTAssertEqual(try finish("swsh9tg-TG01"), .fullArt)
        XCTAssertEqual(try finish("swsh12pt5gg-GG69"), .gold)
    }

    func testSubsetCardsHaveAnUpstreamImageFallback() throws {
        XCTAssertEqual(
            try XCTUnwrap(CardImageSource.upstreamURL(cardID: "sma-SV1", hires: false))
                .absoluteString,
            "https://images.pokemontcg.io/sma/SV1.png"
        )
        XCTAssertEqual(
            try XCTUnwrap(CardImageSource.upstreamURL(cardID: "cel25c-2_A", hires: true))
                .absoluteString,
            "https://images.pokemontcg.io/cel25c/2_A_hires.png"
        )
        let urls = CardImageSource.urls(cardID: "swsh9tg-TG01", hires: false)
        XCTAssertGreaterThanOrEqual(urls.count, 2)
        XCTAssertEqual(Set(urls).count, urls.count)
        XCTAssertTrue(try XCTUnwrap(CardImageSource.upstreamURL(cardID: "ex10-?", hires: true))
            .absoluteString.contains("/question_hires.png"))
    }
}
