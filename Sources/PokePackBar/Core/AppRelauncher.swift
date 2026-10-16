import AppKit

/// 앱을 다시 시작한다. 온라인 모드 전환이나 다른 계정 연결처럼 기동할 때 정해지는 설정에 쓴다.
///
/// 정상 종료는 launchd 가 다시 띄우지 않으므로(`KeepAlive.SuccessfulExit=false`) 직접 띄운다.
/// 새 인스턴스는 이 프로세스가 끝난 뒤에 연다 — 먼저 뜨면 실행 중인 인스턴스에 양보하고 바로 꺼진다.
@MainActor
enum AppRelauncher {
    /// 다시 뜬 앱이 온라인 창을 바로 연다. 다른 계정으로 로그인한 뒤에 쓴다.
    nonisolated static let openOnlineArgument = "--open-online"

    /// 다시 띄우지 못하면 `false` 를 돌려주고 앱은 그대로 둔다. 부르는 쪽이 직접 다시 시작하라고 안내한다.
    @discardableResult
    static func relaunch(openingOnline: Bool = false) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = helperArguments(pid: ProcessInfo.processInfo.processIdentifier,
                                         bundlePath: Bundle.main.bundleURL.path, openingOnline: openingOnline)
        do {
            try task.run()
        } catch {
            AppLog.write("relaunch helper failed: \(error.localizedDescription)")
            return false
        }
        NSApp.terminate(nil)
        return true
    }

    /// 이 프로세스가 끝나기를 기다렸다가 같은 번들을 다시 여는 셸 인자. 번들 경로는 `$0` 으로 넘겨
    /// 공백이 든 경로(「PokePackBar Dev.app」)도 그대로 연다.
    nonisolated static func helperArguments(pid: Int32, bundlePath: String, openingOnline: Bool) -> [String] {
        let open = openingOnline ? "/usr/bin/open \"$0\" --args \(openOnlineArgument)" : "/usr/bin/open \"$0\""
        return ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; \(open)", bundlePath]
    }
}
