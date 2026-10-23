import AppKit

/// 창을 앞으로 가져온다.
///
/// 레이아웃 감사는 온라인 창과 계정 창이 실제로 열리고 닫히는지 본다. 그때 창을 그대로 띄우면
/// 감사를 돌리는 동안 작업 중인 사람의 화면 한가운데에 창이 뜨고 앱이 앞으로 나왔다. 감사 중에는
/// 창을 투명하게, 클릭은 통과시키고, 앱을 앞으로 가져오지 않고 연다. 창이 열린 상태(`isVisible`)는
/// 그대로라 감사의 확인은 바뀌지 않는다.
@MainActor
enum WindowPresentation {
    /// 감사 프로세스가 시작할 때 켠다. 감사는 끝나면 프로세스를 끝내므로 다시 끄지 않는다.
    static var quiet = false

    static func present(_ window: NSWindow) {
        if quiet {
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.orderFrontRegardless()
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
