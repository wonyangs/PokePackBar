import Foundation
import XCTest
@testable import PokePackBar

/// 정식 앱 옆에 개발용 앱을 함께 띄울 때 나뉘는 것들. 정식 앱은 예전 그대로여야 한다.
@MainActor
final class AppVariantTests: XCTestCase {

    /// Info.plist 에 `PPBDataName` 이 없는 정식 앱은 예전 폴더와 파일 이름을 그대로 쓴다.
    /// 바뀌면 업데이트한 사용자의 세이브가 사라진 것처럼 보인다.
    func testOfficialAppKeepsItsDataFolder() {
        XCTAssertEqual(AppEnv.dataName, "PokePackBar")
        XCTAssertEqual(AppEnv.supportDirectory.lastPathComponent, "PokePackBar")
        XCTAssertEqual(WalletStore.defaultURL().deletingLastPathComponent().lastPathComponent,
                       ProcessInfo.processInfo.environment["PPB_STATE_DIR"].map { URL(fileURLWithPath: $0).lastPathComponent }
                           ?? "PokePackBar")
    }

    /// 정식 앱은 업데이트를 확인한다. 개발용 앱만 끈다.
    func testOfficialAppStillChecksForUpdates() {
        XCTAssertFalse(AppLinks.isDevApp)
        XCTAssertEqual(AppLinks.updateChannel, "stable")
        XCTAssertTrue(AppLinks.updatesConfigured)
    }
}

/// 다른 계정으로 로그인하면 앱이 스스로 다시 떠서 그 계정 화면을 연다.
final class AppRelaunchTests: XCTestCase {

    /// 같은 번들을 다시 열고, 로그인 뒤에는 온라인 창을 열라는 인자를 붙인다. 번들 경로는 셸 문자열에
    /// 넣지 않고 `$0` 으로 넘겨 공백이 든 「PokePackBar Dev.app」도 그대로 연다.
    func testRelaunchReopensTheSameBundleAndCanOpenTheOnlineWindow() {
        let path = "/Applications/PokePackBar Dev.app"
        let plain = AppRelauncher.helperArguments(pid: 42, bundlePath: path, openingOnline: false)
        XCTAssertEqual(plain.first, "-c")
        XCTAssertEqual(plain.last, path)
        XCTAssertTrue(plain[1].hasPrefix("while kill -0 42 "))
        XCTAssertTrue(plain[1].hasSuffix("/usr/bin/open \"$0\""))
        XCTAssertFalse(plain[1].contains(path))

        let online = AppRelauncher.helperArguments(pid: 42, bundlePath: path, openingOnline: true)
        XCTAssertTrue(online[1].hasSuffix("/usr/bin/open \"$0\" --args \(AppRelauncher.openOnlineArgument)"))
        XCTAssertEqual(online.last, path)
    }
}
