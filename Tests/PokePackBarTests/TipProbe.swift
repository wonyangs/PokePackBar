import AppKit
import SwiftUI
import XCTest
@testable import PokePackBar

@MainActor
final class TipProbeTests: XCTestCase {
    private func tooltips(_ view: some View) -> [String] {
        let controller = NSHostingController(rootView: AnyView(view))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 412, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller
        controller.view.layoutSubtreeIfNeeded()
        controller.view.displayIfNeeded()
        var found: [String] = []
        func walk(_ v: NSView) {
            if let tip = v.toolTip { found.append(tip) }
            v.subviews.forEach(walk)
        }
        walk(controller.view)
        return found
    }

    func testProbe() throws {
        // 같은 내용을 HStack 과 WrapLayout 으로 각각 담아 툴팁이 붙는지 견준다.
        let tip = "설명 문구"
        let hstack = HStack {
            ForEach(0..<3, id: \.self) { i in
                Text("항목 \(i)").help("\(tip) \(i)")
            }
        }
        let wrapped = WrapLayout(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Text("항목 \(i)").fixedSize().help("\(tip) \(i)")
            }
        }
        print("PROBE hstack=\(tooltips(hstack))")
        print("PROBE wrap=\(tooltips(wrapped))")
    }
}
