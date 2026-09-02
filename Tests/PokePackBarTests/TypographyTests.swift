import SwiftUI
import XCTest
@testable import PokePackBar

/// 카드 격자가 팝오버 폭 안에 들어오는가.
///
/// 넘치면 넘치는 자식이 팝오버를 밀어 넓혀서 상단 탭까지 흔들린다. 창 폭을 바꿀 때마다
/// 어느 격자가 어긋났는지 눈으로 찾지 않도록 값으로 묶는다.
@MainActor
final class CardGridTests: XCTestCase {

    /// 격자가 제 자리를 넘지 않는가. 견주는 대상은 팝오버 폭이 아니라 **그 격자가 놓이는
    /// 자리**다 — 도감 띠는 줄 카드의 여백 안이라 팝오버보다 좁고, 그것을 잊어 깨졌다.
    func testEveryGridFitsItsBox() {
        for entry in CardGrid.all {
            XCTAssertLessThanOrEqual(entry.grid.totalWidth, entry.grid.available,
                                     "\(entry.name) 격자가 \(entry.grid.totalWidth)pt 로 "
                                     + "제 자리 \(entry.grid.available)pt 를 넘는다")
            XCTAssertLessThanOrEqual(entry.grid.available, PopoverMetrics.contentWidth,
                                     "\(entry.name) 이 팝오버 안쪽보다 넓은 자리를 가정한다")
        }
    }

    /// 남는 자리가 크면 카드가 작아 보인다 — 그것이 "화면과 맞지 않는다" 는 말이었다.
    /// `fitting` 이 나눠 준 값이면 자투리는 칸 수보다 작다.
    func testGridsUseTheWidthTheyHave() {
        for entry in CardGrid.all {
            let slack = entry.grid.available - entry.grid.totalWidth
            XCTAssertLessThan(slack, CGFloat(entry.grid.columns),
                              "\(entry.name) 격자가 \(Int(slack))pt 를 남긴다 — 자리를 다시 나눈다")
        }
    }

    /// 팩 한 개가 개봉 결과에 두 줄로 들어가는가.
    ///
    /// 세 줄이 되면 머리글과 「확인」 버튼까지 더해 탭 높이를 넘고, 결과를 다 보려면
    /// 굴려야 한다 — 한 팩이 한눈에 안 보이면 무엇을 건졌는지 읽히지 않는다.
    ///
    /// **시대마다 팩 장수가 다르다.** 1999년 팩은 11장이라 다섯 열로는 세 줄이 되고,
    /// e-Card·EX 는 9장이다. 어느 시대든 두 줄이어야 한다.
    func testEveryEraFitsTheSummaryInTwoRows() {
        for era in PackEra.allCases {
            let cards = PackConfig.cardsPerPack(era)
            let grid = CardGrid.packSummary(cards)
            let rows = Int((Double(cards) / Double(grid.columns)).rounded(.up))
            XCTAssertLessThanOrEqual(rows, 2,
                                     "\(era) \(cards)장을 열 \(grid.columns)개로 놓으면 \(rows)줄이다")
        }
    }

    /// 도감 띠는 줄 카드 **안에** 들어간다. 띠에 줄 여백을 더한 값이 탭 폭을 넘으면
    /// 줄이 통째로 넓어져 목록이 깨진다 — 실제로 그렇게 깨졌다.
    func testDexStripFitsInsideItsRow() {
        let row = CardGrid.dexStrip.totalWidth + CardGrid.dexRowPadding * 2
        XCTAssertLessThanOrEqual(row, PopoverMetrics.contentWidth - CardGrid.scroller,
                                 "도감 줄이 \(row)pt 로 탭 폭을 넘는다")
    }
}

/// 탭 줄이 주어진 폭을 다 쓰는가.
///
/// macOS 기본 세그먼트 컨트롤은 OS 판에 따라 제 내용 크기로 줄어든다. macOS 26 에서 네 탭이
/// 창 한가운데로 몰렸고, `maxWidth: .infinity` 로도 채워지지 않았다. 직접 그린 뒤로는 폭을
/// 다 쓰지만, 다시 기본 컨트롤로 돌아가면 같은 일이 반복되므로 값으로 묶는다.
@MainActor
final class SegmentedTabsTests: XCTestCase {

    private func width(of view: some View, proposing width: CGFloat) -> CGFloat {
        let controller = NSHostingController(rootView: AnyView(view.frame(width: width)))
        controller.view.layoutSubtreeIfNeeded()
        return controller.sizeThatFits(in: CGSize(width: width, height: 100)).width
    }

    /// **세로로 눌리지 않는다.**
    ///
    /// 자리가 모자라면 SwiftUI 가 줄일 수 있는 자식부터 줄인다. 상단 탭 줄은 높이가 고정된
    /// 탭 내용과 같은 VStack 에 있어 눌리는 쪽이 되고, 탭 안의 갈래 선택은 그 안쪽이라
    /// 안 눌린다 — 같은 부품인데 위는 28pt, 아래는 31pt 로 그려졌다.
    /// 탭 줄 높이는 28pt 다. 두 세그먼트가 같은 값을 써야 한 화면에서 어긋나 보이지 않는다.
    func testTabRowIsTwentyEightPointsTall() {
        var picked = 0
        let tabs = SegmentedTabs(items: (0..<4).map { .init(value: $0, label: "탭 \($0)") },
                                 selection: Binding(get: { picked }, set: { picked = $0 }))
        let host = NSHostingController(rootView: AnyView(tabs))
        XCTAssertEqual(host.sizeThatFits(in: CGSize(width: PopoverMetrics.contentWidth,
                                                    height: 200)).height,
                       28, accuracy: 0.5)
    }

    func testTabsKeepTheirHeightWhenSqueezed() {
        var picked = 0
        let tabs = SegmentedTabs(items: (0..<4).map { .init(value: $0, label: "탭 \($0)") },
                                 selection: Binding(get: { picked }, set: { picked = $0 }))
        let host = NSHostingController(rootView: AnyView(tabs))
        let natural = host.sizeThatFits(in: CGSize(width: PopoverMetrics.contentWidth,
                                                   height: .greatestFiniteMagnitude)).height
        let squeezed = host.sizeThatFits(in: CGSize(width: PopoverMetrics.contentWidth,
                                                    height: 10)).height
        XCTAssertEqual(squeezed, natural, accuracy: 0.5,
                       "자리가 모자라면 탭 줄이 눌린다 — 다른 세그먼트와 높이가 달라진다")
    }

    func testTabsFillTheWidthTheyAreGiven() {
        for count in 2...5 {
            let items = (0..<count).map {
                SegmentedTabs<Int>.Item(value: $0, label: "탭 \($0)")
            }
            let tabs = SegmentedTabs(items: items, selection: .constant(0))
            XCTAssertEqual(width(of: tabs, proposing: PopoverMetrics.contentWidth),
                           PopoverMetrics.contentWidth, accuracy: 0.5,
                           "\(count)칸 탭이 주어진 폭을 다 쓰지 않는다")
        }
    }

    /// 팝오버의 탭 줄과 상점의 구역 줄은 직접 그린 것을 쓴다.
    /// 기본 세그먼트 컨트롤로 돌아가면 OS 판에 따라 다시 몰린다.
    func testTabRowsDoNotUseTheSystemSegmentedControl() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for name in ["PopoverView", "CardShopView"] {
            let text = try String(contentsOf: root.appendingPathComponent(
                "Sources/PokePackBar/UI/\(name).swift"), encoding: .utf8)
            XCTAssertFalse(text.contains("pickerStyle(.segmented)"),
                           "\(name): 기본 세그먼트 컨트롤로 돌아갔다")
            XCTAssertTrue(text.contains("SegmentedTabs("), "\(name): 탭 줄이 사라졌다")
        }
    }
}

/// 뒤로 가기가 화면마다 다른 자리에 있지 않은가.
///
/// 예전에는 목록에서 왼쪽 갈매기, 상세에서 오른쪽 X 였다. 상점에서 시대 → 팩 목록 → 팩
/// 상세로 들어가면 버튼이 왼쪽에 있다 오른쪽으로 건너뛰어 매번 눈으로 찾아야 했다.
@MainActor
final class BackButtonTests: XCTestCase {

    private var uiSources: [URL] {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI")
        return ((try? FileManager.default.contentsOfDirectory(at: dir,
                                                              includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "BackButton.swift" }
    }

    /// 화면을 닫는 버튼을 손으로 그리지 않는다. `BackButton` 하나만 쓴다.
    func testNoHandRolledBackControls() throws {
        var offenders: [String] = []
        for url in uiSources {
            let text = try String(contentsOf: url, encoding: .utf8)
            for glyph in ["xmark.circle", "chevron.left", "chevron.backward"]
            where text.contains(glyph) {
                offenders.append("\(url.lastPathComponent): \(glyph)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "뒤로 가기를 손으로 그렸다. BackButton 을 쓴다: "
                      + offenders.joined(separator: ", "))
    }

    /// 누를 수 있는 넓이가 충분한가.
    ///
    /// 그림만 두면 실제로 눌리는 곳이 글리프 넓이(대략 10×14pt)뿐이라 조금만 빗나가도
    /// 반응하지 않는다. 「눌러도 안 눌린다」는 말이 여기서 나왔다.
    func testBackButtonIsBigEnoughToHit() {
        let controller = NSHostingController(rootView: AnyView(BackButton(action: {})))
        let size = controller.sizeThatFits(in: CGSize(width: 200, height: 100))
        XCTAssertGreaterThanOrEqual(size.width, 28, "가로가 좁아 누르기 어렵다")
        XCTAssertGreaterThanOrEqual(size.height, 24, "세로가 좁아 누르기 어렵다")
    }
}

/// 화면에 쓰이지 않는 문구가 남아 있는가.
///
/// `packTotalValue` 를 문구 표에는 넣고 화면에 붙이는 편집이 조용히 실패한 적이 있다.
/// 컴파일은 통과하므로(쓰이지 않는 함수일 뿐) 눈으로만 잡히는 종류였다.
@MainActor
final class UnusedCopyTests: XCTestCase {

    func testEveryCardCopyIsUsedOnScreen() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let table = try String(contentsOf: root.appendingPathComponent(
            "Sources/PokePackBar/Core/LocalizationCards.swift"), encoding: .utf8)
        let ui = try (FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Sources/PokePackBar/UI"),
            includingPropertiesForKeys: nil))
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined()
        let core = try (FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Sources/PokePackBar/Core"),
            includingPropertiesForKeys: nil))
            .filter { $0.pathExtension == "swift" && !$0.lastPathComponent.hasPrefix("Localization") }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined()

        // 표 안에서 다른 문구를 조립하는 데 쓰이는 것도 있다(혜택 이름 등). 그쪽은 점 없이
        // 그냥 이름으로 부르므로 정의줄을 뺀 나머지에서 찾는다.
        let tableBody = table.split(separator: "\n")
            .filter { !$0.contains("    var ") && !$0.contains("    func ") }
            .joined(separator: "\n")

        var unused: [String] = []
        for line in table.split(separator: "\n") {
            guard let range = line.range(of: #"(?:var|func) (\w+)"#, options: .regularExpression)
            else { continue }
            let name = String(line[range].split(separator: " ")[1])
            guard name != "t", !name.hasPrefix("percent") else { continue }
            if !ui.contains(".\(name)"), !core.contains(".\(name)"), !tableBody.contains(name) {
                unused.append(name)
            }
        }
        XCTAssertTrue(unused.isEmpty,
                      "문구만 있고 화면에 안 붙은 것: \(unused.joined(separator: ", "))")
    }
}

/// 글자 크기 정책을 소스에서 지킨다.
///
/// 화면마다 크기를 손으로 고르다 보니 같은 성격의 글자가 화면마다 달랐고, 좁은 창에 맞추느라
/// 전체가 계속 작아졌다. 크기는 `Typography` 에만 두고, 화면은 역할로만 고른다.
final class TypographyTests: XCTestCase {

    private static var uiSources: [URL] {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/UI")
        let all = (try? FileManager.default.contentsOfDirectory(at: dir,
                                                                includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.pathExtension == "swift" && $0.lastPathComponent != "Typography.swift" }
    }

    /// 13pt 아래는 두지 않는다. 메뉴바에서 잠깐 열어 보는 창이라 읽히지 않는다.
    func testNoTypeBelowTheFloor() throws {
        var offenders: [String] = []
        for url in Self.uiSources {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated() {
                for match in line.ranges(of: try Regex(#"size: (\d+)"#)) {
                    let size = Int(line[match].dropFirst("size: ".count)) ?? 99
                    if size < Int(Typography.minimumSize) {
                        offenders.append("\(url.lastPathComponent):\(index + 1) (\(size)pt)")
                    }
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "\(Int(Typography.minimumSize))pt 아래 글자가 있다. 자리가 모자라면 글자를 "
                      + "줄이지 말고 줄 수를 줄이거나 창을 넓힌다: \(offenders.joined(separator: ", "))")
    }

    /// 시스템 시맨틱 폰트를 직접 쓰지 않는다. `.caption` 과 `.footnote` 가 섞이면
    /// 같은 성격의 글자가 화면마다 다른 크기가 된다.
    func testNoRawSemanticFonts() throws {
        let banned = [".font(.caption", ".font(.footnote", ".font(.subheadline",
                      ".font(.callout", ".font(.body", ".font(.title"]
        var offenders: [String] = []
        for url in Self.uiSources {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated() where banned.contains(where: { line.contains($0) }) {
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "Typography 의 역할 이름을 쓴다: \(offenders.joined(separator: ", "))")
    }

    /// 버튼 글자가 정책 밖으로 빠져나가지 않는가.
    ///
    /// `.controlSize(.small)` 은 11pt, `.mini` 는 9pt 로 그린다. `Typography` 를 아무리
    /// 손봐도 버튼만 작게 남으므로 버튼에는 쓰지 않는다. 스위치와 진행 표시는 글자가
    /// 없으니 상관없다.
    func testButtonsDoNotUseSmallControlSizes() throws {
        var offenders: [String] = []
        for url in Self.uiSources {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
            where line.contains(".controlSize(.small)") || line.contains(".controlSize(.mini)") {
                if line.contains("toggleStyle") || line.contains("ProgressView") { continue }
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
                      "버튼에 작은 컨트롤 크기를 쓰면 글자가 11pt·9pt 로 떨어진다. "
                      + "기본 크기에 Typography.button 을 쓸 것: \(offenders.joined(separator: ", "))")
    }

    /// 정책 자체가 뒤집히지 않았는가 — 곁다리가 본문보다 크면 안 된다.
    func testScaleRisesWithImportance() {
        XCTAssertEqual(Typography.minimumSize, 13)
        for (small, large) in [(Typography.caption, Typography.label),
                               (Typography.label, Typography.body),
                               (Typography.body, Typography.title),
                               (Typography.title, Typography.heading)] {
            XCTAssertNotEqual(small, large, "역할이 같은 크기를 쓰면 구분이 사라진다")
        }
    }
}
