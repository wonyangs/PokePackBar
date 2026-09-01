import AppKit
import XCTest
@testable import PokePackBar

@MainActor
final class PopoverNavigationTests: XCTestCase {

    /// 팝오버를 처음 열면 상점이다. 살 것을 먼저 보여주는 것이 이 앱의 시작점이다.
    func testDefaultsToShop() {
        XCTAssertEqual(PopoverNavigation().tab, .shop)
    }

    /// **팝오버를 닫아도 보던 화면이 남는다.**
    ///
    /// 예전에는 닫을 때 화면 트리를 버리고 열 때 상점으로 되돌렸다. 팩을 뜯다 닫으면 뜯던
    /// 장 번호도 무엇이 나왔는지도 사라졌다. 트리를 버리지 않고 되돌리지도 않으므로,
    /// 되돌리는 코드가 다시 생기면 그 증상이 그대로 돌아온다.
    func testNothingResetsTheScreenOnReopen() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent(
            "Sources/PokePackBar/PokePackBarApp.swift"), encoding: .utf8)

        XCTAssertFalse(app.contains("navigation.reset()"),
                       "열 때 화면을 되돌리고 있다 — 뜯던 팩이 사라진다")
        XCTAssertFalse(app.contains("contentViewController = nil"),
                       "닫을 때 화면 트리를 버리고 있다 — @State 가 함께 죽는다")
        // 트리는 한 번만 만든다. 열 때마다 만들면 버리지 않아도 상태가 사라진다.
        XCTAssertTrue(app.contains("if popover.contentViewController == nil { buildPopoverContent() }"),
                      "트리를 열 때마다 새로 만들고 있다")
    }

    /// **카드 상세에서 그 카드가 나오는 팩을 사러 갈 수 있어야 한다.**
    ///
    /// 갖고 싶은 카드를 크게 보고 있을 때 다음에 하고 싶은 일이 그것이다. 예전에는 팩
    /// 이름만 적혀 있어서, 상점으로 가 시대를 짚어 가며 같은 팩을 눈으로 다시 찾아야 했다.
    ///
    /// 상점 쪽에는 그 요청을 받아 팩 상세를 여는 자리가 이미 있다(도감의 「이 팩 사러 가기」
    /// 가 쓰던 길이다). 두 쪽이 다 있어야 이어지므로 함께 검사한다.
    func testCardDetailCanReachThePackInTheShop() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI")
        let spotlight = try String(contentsOf: sources.appendingPathComponent("CardSpotlightView.swift"),
                                   encoding: .utf8)
        let shop = try String(contentsOf: sources.appendingPathComponent("CardShopView.swift"),
                              encoding: .utf8)

        XCTAssertTrue(spotlight.contains("nav.shopSet = setID"),
                      "카드 상세에서 팩을 눌러도 상점으로 가지 않는다")
        XCTAssertTrue(spotlight.contains("nav.tab = .shop"),
                      "팩을 지목만 하고 상점 탭으로 옮기지 않는다 — 아무 일도 안 일어난다")
        XCTAssertTrue(shop.contains("nav.shopSet = nil"),
                      "상점이 요청을 지우지 않는다 — 다음에 상점을 열 때 또 그 팩이 뜬다")
        // 이미 그 팩 안에서 연 카드에는 링크를 걸지 않는다 — 눌러도 제자리다.
        XCTAssertTrue(shop.contains("canVisitPack: false"),
                      "팩 안에서 연 카드에 제자리로 가는 버튼이 남아 있다")
    }

    /// **팩 상세에서 그 팩의 카드를 다 볼 수 있어야 한다.**
    ///
    /// 확률표는 등급별 비중만 말해 준다. 「이 팩에 무엇이 들었나」는 결국 카드를 봐야 알고,
    /// 그걸 모르면 살지 말지 정할 수가 없다.
    func testPackDetailListsItsCards() throws {
        let shop = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI/CardShopView.swift"), encoding: .utf8)
        XCTAssertTrue(shop.contains("browsingCards = true"), "카드 목록으로 들어갈 길이 없다")
        // 못 얻은 카드도 보여야 한다. 가진 것만 보여 주면 무엇을 노리고 사는지 알 수 없다.
        XCTAssertTrue(shop.contains("index.cardsByValue.filter { $0.setID == set.id }"),
                      "목록이 세트 전체가 아니거나 값순이 아니다")
    }

    /// 끝없이 도는 애니메이션은 팝오버가 보일 때만 돌아야 한다.
    ///
    /// 트리를 닫아도 버리지 않으므로, 걸어 둔 `repeatForever` 는 닫힌 채로도 계속 다시
    /// 그린다. 오리파 가림막의 숨쉬기가 그것이다 — 창 표시 상태를 봐야 한다.
    func testEndlessAnimationsWatchWindowVisibility() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let ui = root.appendingPathComponent("Sources/PokePackBar/UI")
        for case let url as URL in try XCTUnwrap(FileManager.default.enumerator(
            at: ui, includingPropertiesForKeys: nil)) where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard text.contains("repeatForever") else { continue }
            // 잠깐 떴다 사라지는 화면(개봉 대기)은 스스로 없어지므로 뺀다.
            guard url.lastPathComponent != "PacksView.swift" else { continue }
            XCTAssertTrue(text.contains("nav.isShown"),
                          "\(url.lastPathComponent): 끝없는 애니메이션이 창 표시 상태를 안 본다")
        }
    }

    /// 화면 상태를 담는 자리는 남아 있어야 한다 — 여기가 비면 닫았다 열 때 돌아갈 곳이 없다.
    func testNavigationKeepsWhereYouWere() {
        let nav = PopoverNavigation()
        nav.tab = .packs
        nav.showSettings = true
        XCTAssertEqual(nav.tab, .packs)
        XCTAssertTrue(nav.showSettings)
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
