import AppKit
import XCTest
@testable import PokePackBar

/// 메뉴바에 올릴 카드를 고르는 규칙과, 그것을 22pt 아이콘으로 합성하는 기하.
///
/// 메뉴바는 한 번 잘못되면 사용자가 하루 종일 보는 자리라 규칙을 값으로 못박아 둔다.
final class MenuBarCardTests: XCTestCase {

    private static let index = try! XCTUnwrap(CardIndex.loadBundled())

    /// 실제 번들 인덱스에서 등급별로 한 장씩 골라 온다 — 손으로 적은 가짜 카드로는
    /// 세트 출시일 동률 처리를 검증할 수 없다.
    private func card(_ tier: CardTier, set: String? = nil) throws -> CardEntry {
        let match = Self.index.cards.first {
            $0.tier == tier && (set == nil || $0.setID == set)
        }
        return try XCTUnwrap(match, "\(tier.rawValue) 등급 카드가 인덱스에 없다")
    }

    // MARK: 고르는 순서

    func testFavoriteWins() throws {
        let common = try card(.common)
        let ultra = try card(.ultraRare)
        let picked = MenuBarCard.resolve(favorite: common.id,
                                         owned: [common.id: 1, ultra.id: 1],
                                         index: Self.index)
        XCTAssertEqual(picked?.id, common.id, "최애 카드는 등급이 낮아도 이긴다")
    }

    /// 최애가 손에 없으면 자동 선택으로 내려가야 한다. 없는 카드를 가리킨 채 두면
    /// 메뉴바 아이콘이 조용히 사라진다.
    func testFavoriteNotOwnedFallsThrough() throws {
        let common = try card(.common)
        let ultra = try card(.ultraRare)
        let picked = MenuBarCard.resolve(favorite: ultra.id,
                                         owned: [common.id: 1],
                                         index: Self.index)
        XCTAssertEqual(picked?.id, common.id)
    }

    func testFavoriteOfUnknownCardFallsThrough() throws {
        let common = try card(.common)
        let picked = MenuBarCard.resolve(favorite: "no-such-card-9999",
                                         owned: [common.id: 1],
                                         index: Self.index)
        XCTAssertEqual(picked?.id, common.id)
    }

    func testPicksHighestTier() throws {
        let owned = [try card(.common).id: 1, try card(.rare).id: 1,
                     try card(.superRare).id: 1, try card(.uncommon).id: 1]
        let picked = MenuBarCard.resolve(favorite: nil, owned: owned, index: Self.index)
        XCTAssertEqual(picked?.tier, .superRare)
    }

    func testNoCardsGivesNil() {
        XCTAssertNil(MenuBarCard.resolve(favorite: nil, owned: [:], index: Self.index))
    }

    /// 기본 에너지만 갖고 있으면 기존 기호로 남는다 — 메뉴바에 에너지 카드는 상이 아니다.
    func testEnergyOnlyGivesNil() throws {
        let energy = try card(.energy)
        XCTAssertNil(MenuBarCard.resolve(favorite: nil, owned: [energy.id: 3], index: Self.index))
        XCTAssertNil(MenuBarCard.resolve(favorite: energy.id, owned: [energy.id: 3],
                                         index: Self.index))
    }

    /// 0장으로 남은 항목은 갖고 있지 않은 것이다.
    func testZeroCountIsNotOwned() throws {
        let common = try card(.common)
        XCTAssertNil(MenuBarCard.resolve(favorite: nil, owned: [common.id: 0], index: Self.index))
    }

    // MARK: 동률 규칙

    /// 획득 시각을 저장하지 않으므로 규칙으로 고정한다. 같은 보유 상태면 항상 같은 카드가
    /// 나와야 한다 — 켤 때마다 아이콘이 바뀌면 고장으로 보인다.
    func testSameTierIsDeterministic() throws {
        let owned = Dictionary(uniqueKeysWithValues:
            Self.index.cards.filter { $0.tier == .doubleRare }.prefix(12).map { ($0.id, 1) })
        let first = MenuBarCard.resolve(favorite: nil, owned: owned, index: Self.index)?.id
        for _ in 0..<20 {
            XCTAssertEqual(MenuBarCard.resolve(favorite: nil, owned: owned,
                                               index: Self.index)?.id, first)
        }
    }

    /// 같은 등급이면 새로 나온 세트를 먼저 쓴다.
    func testSameTierPrefersNewerSet() throws {
        let old = try card(.doubleRare, set: "base1")
        let new = try card(.doubleRare, set: "sv10")
        let picked = MenuBarCard.resolve(favorite: nil, owned: [old.id: 1, new.id: 1],
                                         index: Self.index)
        XCTAssertEqual(picked?.setID, "sv10")
    }

    /// 같은 세트·같은 등급이면 카드 번호가 앞인 것.
    func testSameSetPrefersLowerNumber() throws {
        let sameSet = Self.index.cards
            .filter { $0.setID == "sv10" && $0.tier == .doubleRare }
            .sorted { MenuBarCard.number($0.id) < MenuBarCard.number($1.id) }
        try XCTSkipIf(sameSet.count < 2, "sv10 에 RR 이 두 장 이상 있어야 한다")
        let owned = Dictionary(uniqueKeysWithValues: sameSet.map { ($0.id, 1) })
        let picked = MenuBarCard.resolve(favorite: nil, owned: owned, index: Self.index)
        XCTAssertEqual(picked?.id, sameSet[0].id)
    }

    func testNumberParsesTail() {
        XCTAssertEqual(MenuBarCard.number("sv8pt5-160"), 160)
        XCTAssertEqual(MenuBarCard.number("base1-1"), 1)
        XCTAssertEqual(MenuBarCard.number("sv3pt5-GG01"), .max, "숫자가 아니면 뒤로 보낸다")
    }

    // MARK: 아이콘 기하

    /// 세로는 메뉴바 두께에 고정한다. 카드마다 흔들리면 옆의 사용량 숫자와 밑선이 어긋난다.
    func testLayoutFixesHeightAndKeepsAspect() {
        for size in [CGSize(width: 733, height: 1024), CGSize(width: 600, height: 825),
                     CGSize(width: 245, height: 342)] {
            let layout = MenuBarCardImage.layout(for: size, thickness: 22)
            XCTAssertEqual(layout.canvas.height, 22)
            let want = size.width / size.height
            let got = layout.rect.width / layout.rect.height
            XCTAssertEqual(got, want, accuracy: 0.06, "비율이 어긋났다 (\(size))")
        }
    }

    /// 카드가 캔버스를 넘어가면 메뉴바에서 잘린다.
    func testLayoutStaysInsideCanvas() {
        for thickness in [20.0, 22.0, 24.0, 26.0] {
            let layout = MenuBarCardImage.layout(for: CGSize(width: 733, height: 1024),
                                                 thickness: thickness)
            XCTAssertGreaterThanOrEqual(layout.rect.minX, 0)
            XCTAssertGreaterThanOrEqual(layout.rect.minY, 0)
            XCTAssertLessThanOrEqual(layout.rect.maxX, layout.canvas.width)
            XCTAssertLessThanOrEqual(layout.rect.maxY, layout.canvas.height)
        }
    }

    /// 두께가 커지면 카드도 커진다 — 노치 있는 화면과 없는 화면의 두께가 다르다.
    func testLayoutFollowsThickness() {
        let small = MenuBarCardImage.layout(for: CGSize(width: 733, height: 1024), thickness: 22)
        let large = MenuBarCardImage.layout(for: CGSize(width: 733, height: 1024), thickness: 26)
        XCTAssertGreaterThan(large.rect.height, small.rect.height)
        XCTAssertGreaterThan(large.canvas.width, small.canvas.width)
    }

    /// 세로가 0 인 이미지가 들어와도 0 으로 나누지 않는다.
    func testLayoutSurvivesDegenerateSize() {
        let layout = MenuBarCardImage.layout(for: .zero, thickness: 22)
        XCTAssertGreaterThan(layout.rect.width, 0)
        XCTAssertEqual(layout.canvas.height, 22)
    }

    /// 합성 결과가 캔버스 크기를 그대로 갖고, 템플릿이 아니어야 한다 —
    /// 템플릿이면 메뉴바가 단색으로 칠해 카드 그림이 사라진다.
    func testComposedImageIsColoured() {
        let source = NSImage(size: NSSize(width: 733, height: 1024))
        let image = MenuBarCardImage.image(from: source, thickness: 22)
        XCTAssertEqual(image.size.height, 22)
        XCTAssertFalse(image.isTemplate)
    }
}
