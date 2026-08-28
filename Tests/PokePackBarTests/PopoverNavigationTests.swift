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

/// 세그먼트 컨트롤은 폭을 반드시 명시해야 한다.
///
/// 적지 않으면 OS 판에 따라 제 내용 크기로 줄어 왼쪽에 몰린다 — 실제로 테스터 기기에서만
/// 그렇게 나왔다. 개발 기기에서 꽉 차게 보이는 한 이 차이는 눈으로 잡히지 않으므로
/// 소스를 훑어 막는다.
final class SegmentedPickerWidthTests: XCTestCase {
    func testEverySegmentedPickerDeclaresItsWidth() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: ui,
                                                                     includingPropertiesForKeys: nil))
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let lines = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (offset, line) in lines.enumerated() where line.contains(".pickerStyle(.segmented)") {
                // 뒤따르는 몇 줄 안에 폭 선언이 있어야 한다(주석이 사이에 낄 수 있다).
                // 같은 줄에 붙는 경우도 있어 앞뒤를 함께 본다.
                let start = max(0, offset - 1)
                let window = lines[start..<min(offset + 8, lines.count)].joined()
                // 꽉 채우든(.infinity) 내용에 맞추든(.fixedSize) 명시만 하면 된다.
                // 금지하는 것은 "아무것도 안 적어 OS 기본에 맡기는 것" 이다.
                let declared = window.contains("maxWidth: .infinity")
                    || window.contains("width:") || window.contains("fixedSize()")
                if !declared { offenders.append("\(url.lastPathComponent):\(offset + 1)") }
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            세그먼트 컨트롤에 폭 선언이 없다. OS 에 따라 왼쪽으로 몰린다.
            .frame(maxWidth: .infinity) 를 붙인다: \(offenders.joined(separator: ", "))
            """)
    }
}
