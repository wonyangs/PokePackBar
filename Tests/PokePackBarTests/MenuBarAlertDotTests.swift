import AppKit
import XCTest
@testable import PokePackBar

/// 안 읽은 알림이 있을 때 메뉴바 아이콘 오른쪽 위에 붙는 빨간 점의 자리.
@MainActor
final class MenuBarAlertDotTests: XCTestCase {

    /// 기본 아이콘은 정렬 영역(겹친 줄을 뺀 큰 사각형)의 오른쪽 위 모서리 안쪽에 점이 붙는다.
    /// 버튼은 그 정렬 영역을 이미지 자리로 잡는다(실측: 그림 17x18, 정렬 영역 16.5x9).
    func testDotSitsOnTheSymbolBody() throws {
        let symbol = try XCTUnwrap(NSImage(systemSymbolName: "rectangle.stack.fill", accessibilityDescription: nil))
        symbol.isTemplate = true
        let content = MenuBarAlertDot.content(of: symbol)
        XCTAssertEqual(content, symbol.alignmentRect)
        let imageRect = NSRect(origin: NSPoint(x: 0, y: (22 - content.height) / 2), size: content.size)
        let frame = MenuBarAlertDot.frame(imageRect: imageRect, alignment: symbol.alignmentRect,
                                          content: content, flipped: true)
        XCTAssertEqual(frame.midX, imageRect.maxX - MenuBarAlertDot.inset, accuracy: 0.5)
        XCTAssertEqual(frame.midY, imageRect.minY + MenuBarAlertDot.inset, accuracy: 0.5)
    }

    /// 카드 아이콘은 그림에 여백이 있어 카드 모서리에 붙여야 한다. 그림 모서리에 두면 카드에서
    /// 떨어져 떠 보인다. 점은 메뉴바(두께 22) 안에 다 들어와야 한다.
    func testDotSitsOnTheCardCornerInsideTheMenuBar() {
        let canvas = NSSize(width: 15, height: 22)
        let card = NSImage(size: canvas)
        card.isTemplate = false
        let content = MenuBarAlertDot.content(of: card)
        XCTAssertEqual(content, NSRect(x: 1, y: 2, width: 13, height: 18))
        let frame = MenuBarAlertDot.frame(imageRect: NSRect(origin: NSPoint(x: 4, y: 0), size: canvas),
                                          alignment: NSRect(origin: .zero, size: canvas), content: content, flipped: true)
        // 카드 모서리(오른쪽 18, 위 2)에서 2pt 안쪽이 점 중심이다. 모서리에 걸쳐 앉는다.
        XCTAssertEqual(frame, NSRect(x: 13, y: 1, width: 6, height: 6))
        XCTAssertGreaterThanOrEqual(frame.minY, 0)
    }

    /// 뒤집히지 않은 좌표(아래가 0)에서도 같은 모서리에 붙는다.
    func testUnflippedButtonsGetTheSameCorner() {
        let body = NSRect(x: 0, y: 0, width: 16, height: 14)
        let rect = NSRect(x: 4, y: 4, width: 16, height: 14)
        XCTAssertEqual(MenuBarAlertDot.frame(imageRect: rect, alignment: body, content: body, flipped: true),
                       NSRect(x: 15, y: 3, width: 6, height: 6))
        XCTAssertEqual(MenuBarAlertDot.frame(imageRect: rect, alignment: body, content: body, flipped: false),
                       NSRect(x: 15, y: 13, width: 6, height: 6))
    }
}
