import AppKit
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

    /// 기획에 필요한 탭만 둔다 — 팩을 사고, 팩을 열고, 카드를 보고, 조합을 모은다.
    func testExposesExactlyFourTabs() {
        XCTAssertEqual(PopoverTab.allCases.count, 4)
        XCTAssertEqual(PopoverTab.allCases, [.shop, .packs, .collection, .dex])
    }

    /// 탭 라벨이 팝오버 폭에 들어가는가.
    ///
    /// 개수만 고정하면 언어를 하나 늘리거나 라벨을 길게 쓸 때 잘리는 것을 못 잡는다.
    /// 실제 폰트로 재서 6개 언어 전부를 검사한다 — 잘리는 언어는 쓰는 사람만 겪는다.
    @MainActor
    func testTabLabelsFitEveryLanguage() {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        // NSSegmentedControl 은 라벨 좌우로 여백을 둔다. 실측이 어려워 넉넉히 잡는다.
        let paddingPerSegment: CGFloat = 22

        for language in AppLanguage.allCases {
            let l = L(language)
            let labels = [l.shop, l.packsTab, l.collection, l.dexTab]
            let width = labels.reduce(0.0) { total, label in
                total + NSAttributedString(string: label, attributes: [.font: font])
                    .size().width + paddingPerSegment
            }
            XCTAssertLessThanOrEqual(width, PopoverMetrics.contentWidth,
                                     "\(language): 탭 라벨 \(Int(width))pt 가 폭을 넘는다 — \(labels)")
        }
    }
}
