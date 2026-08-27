import XCTest
@testable import PokePackBar

@MainActor
final class PopoverNavigationTests: XCTestCase {

    /// 팝오버를 처음 열면 상점이다. 살 것을 먼저 보여주는 것이 이 앱의 시작점이다.
    func testDefaultsToShop() {
        XCTAssertEqual(PopoverNavigation().tab, .shop)
    }

    /// 호스팅 컨트롤러는 팝오버를 닫아도 재사용되므로 화면 상태가 남는다.
    /// 열 때마다 reset() 해서 항상 같은 자리에서 시작하게 한다.
    func testResetReturnsToShopAndClosesSettings() {
        let nav = PopoverNavigation()
        nav.tab = .collection
        nav.showSettings = true

        nav.reset()

        XCTAssertEqual(nav.tab, .shop)
        XCTAssertFalse(nav.showSettings)
    }

    /// 기획에 필요한 탭만 둔다 — 팩을 사고, 팩을 열고, 카드를 본다.
    /// 탭이 늘면 팝오버 폭 332 에서 세그먼트 라벨이 잘리므로 개수를 고정해 둔다.
    func testExposesExactlyThreeTabs() {
        XCTAssertEqual(PopoverTab.allCases.count, 3)
        XCTAssertEqual(PopoverTab.allCases, [.shop, .packs, .collection])
    }
}
