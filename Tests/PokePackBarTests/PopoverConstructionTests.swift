import AppKit
import SwiftUI
import XCTest
@testable import PokePackBar

/// 팝오버를 실제로 만들어 레이아웃까지 돌린다.
///
/// 이 경로는 메뉴바를 클릭해야만 지나가므로 자동 검증이 없었다. 뷰 본문에서 죽으면
/// 앱이 통째로 사라지는데(테스터 리포트), 로그에는 아무것도 안 남는다.
@MainActor
final class PopoverConstructionTests: XCTestCase {

    private func hostAndLayout<V: View>(_ view: V) {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller
        controller.view.layoutSubtreeIfNeeded()
        // 본문 평가를 강제한다 — 붙이기만 하면 게으르게 미뤄질 수 있다.
        controller.view.displayIfNeeded()
    }

    private func makeEnvironment() -> (UsageStore, WalletStore, UpdateChecker, PopoverNavigation) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("popover-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
        return (UsageStore(), wallet, UpdateChecker(currentVersion: "0.0.0"), PopoverNavigation())
    }

    /// 앱이 팝오버를 열 때 만드는 것과 같은 트리.
    func testPopoverBuildsForEveryTab() {
        let (store, wallet, updater, nav) = makeEnvironment()
        for tab in PopoverTab.allCases {
            nav.tab = tab
            hostAndLayout(PopoverView()
                .environment(store).environment(wallet)
                .environment(updater).environment(nav))
        }
    }

    /// 설정 화면도 같은 트리 안에서 열린다.
    func testSettingsBuilds() {
        let (store, wallet, updater, nav) = makeEnvironment()
        nav.showSettings = true
        hostAndLayout(PopoverView()
            .environment(store).environment(wallet)
            .environment(updater).environment(nav))
    }

    /// 카드를 가진 상태 — 컬렉션 격자와 등급 현황이 실제 데이터로 그려진다.
    func testCollectionBuildsWithOwnedCards() throws {
        let (store, wallet, updater, nav) = makeEnvironment()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        wallet.collect(index.cards.prefix(40).map(\.id))
        nav.tab = .collection
        hostAndLayout(PopoverView()
            .environment(store).environment(wallet)
            .environment(updater).environment(nav))
    }

    /// 미개봉 팩을 가진 상태 — 팩 목록이 그려진다.
    func testPacksBuildWithOwnedPack() throws {
        let (store, wallet, updater, nav) = makeEnvironment()
        let index = try XCTUnwrap(CardIndex.loadBundled())
        wallet.addPack(setID: try XCTUnwrap(index.setIDs.first))
        nav.tab = .packs
        hostAndLayout(PopoverView()
            .environment(store).environment(wallet)
            .environment(updater).environment(nav))
    }
}

/// 알림 API 는 반드시 `AppEnv.canUseNotifications` 를 거쳐야 한다.
///
/// `UNUserNotificationCenter.current()` 는 LaunchServices 가 번들을 모르면
/// Objective-C 예외를 던지고, Swift 의 `try?` 로는 잡히지 않아 프로세스가 죽는다.
/// 새로 설치한 테스터에게만 앱이 사라지는 증상이 여기서 나왔다.
final class NotificationGuardTests: XCTestCase {

    func testEveryNotificationCallSiteIsGuarded() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar")

        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() where line.contains("UNUserNotificationCenter")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                // 주석은 뺀다 — 가드 함수 자신의 설명이 API 이름을 언급한다.
                // 같은 함수 안에서 앞쪽에 가드가 있는지 본다. 함수 경계는 들여쓰기 4칸 닫는 괄호.
                var guarded = false
                var j = i
                while j > 0 {
                    j -= 1
                    let prev = lines[j]
                    if prev.contains("AppEnv.canUseNotifications") { guarded = true; break }
                    if prev == "    }" { break }   // 함수 시작 위로 넘어갔다
                }
                if !guarded { offenders.append("\(url.lastPathComponent):\(i + 1)") }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            알림 API 를 가드 없이 호출한다. LaunchServices 가 번들을 모르면 ObjC 예외로 앱이 죽는다.
            AppEnv.canUseNotifications 를 먼저 확인할 것: \(offenders.joined(separator: ", "))
            """)
    }

    /// 번들이 아닌 테스트 실행에서는 알림을 쓸 수 없다고 나와야 한다.
    func testNotificationsUnavailableOutsideAnAppBundle() {
        XCTAssertFalse(AppEnv.canUseNotifications)
    }
}

/// 리소스 번들을 찾는 경로. 여기가 어긋나면 빌드한 컴퓨터에서만 동작하고
/// 배포된 앱은 첫 클릭에 죽는다 — 실제로 v0.1.0 이 그렇게 나갔다.
final class AppResourcesTests: XCTestCase {

    func testResourceBundleResolves() throws {
        XCTAssertNotNil(AppResources.bundle, "리소스 번들을 찾지 못했다")
        XCTAssertNil(AppResources.verify(), "리소스 확인이 실패했다")
    }

    /// `Bundle.module` 은 찾지 못하면 fatalError 로 프로세스를 죽인다.
    /// 게다가 폴백이 빌드 기계의 절대경로라, 빌드한 컴퓨터에서는 통과하고
    /// 다른 컴퓨터에서만 죽는다. 앱 코드에서 쓰지 않는다.
    func testSourcesDoNotUseBundleModule() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar")

        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains("Bundle.module")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                offenders.append("\(url.lastPathComponent):\(i + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            Bundle.module 은 찾지 못하면 앱을 죽이고, 폴백이 빌드 기계 경로라 배포 후에만 드러난다.
            AppResources.bundle 을 쓸 것: \(offenders.joined(separator: ", "))
            """)
    }

    /// `.app` 배치(Contents/Resources)를 가장 먼저 본다.
    /// 이 순서가 바뀌면 build-app.sh 가 넣는 위치와 어긋난다.
    func testLooksInAppResourcesFirst() {
        let paths = AppResources.candidateURLs().map(\.path)
        let appLayout = Bundle.main.resourceURL?
            .appendingPathComponent(AppResources.bundleName).path
        if let appLayout {
            XCTAssertEqual(paths.first, appLayout, "Contents/Resources 를 먼저 봐야 한다")
        }
    }
}
