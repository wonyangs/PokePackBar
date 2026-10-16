import AppKit
import Foundation

/// 실행 환경 판별 — 한 곳에서만 정의해 중복 게이트의 drift(일부만 조건이 어긋나는 것)를 막는다.
enum AppEnv {
    /// 정식 `.app` 번들로 실행 중인가. 알림 전송·키체인 읽기·스프라이트 프리패치·프로덕션 로그 기록 등
    /// "실앱 전용" 부수효과의 단일 게이트 — `swift test`/로우 바이너리(dev 실행)에선 false.
    /// bundleIdentifier(Info.plist)와 경로 접미사를 함께 확인(둘 다 실앱에서만 참).
    static var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// 알림 API 를 건드려도 안전한가.
    ///
    /// `UNUserNotificationCenter.current()` 는 LaunchServices 가 이 번들을 모르면
    /// Objective-C 예외를 던진다. Swift 의 `try?` 는 ObjC 예외를 잡지 못하므로
    /// 그대로 프로세스가 죽는다 — 메뉴바에서 앱이 사라지고 로그에는 아무것도 안 남는다.
    ///
    /// 등록 여부는 LaunchServices 에 직접 물어본다. 번들 ID 로 앱을 찾지 못하면
    /// 알림 API 를 건드리지 않는다. 새로 복사한 앱이 아직 등록되기 전이거나,
    /// 서명이 불안정해 등록이 거부된 경우가 여기 해당한다.
    /// 개발, QA, 서버 규칙 실행에서만 쓰는 `PPB_*` 설정값(서버 주소, 게이트웨이 키, 그림 폴더 등).
    ///
    /// 사용자가 셸에 export 해 두는 사용량 위치가 아니라 프로세스를 띄우는 쪽이 넘기는 값이라
    /// `UsageEnvironment` 의 셸 조회를 거치지 않는다. 직접 읽는 곳을 여기 하나로 모아,
    /// 사용량 위치를 직접 읽는 실수만 테스트가 잡게 한다.
    static func value(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// 세이브, 캐시, 로그 파일에 붙는 이름. 정식 앱은 「PokePackBar」다. 정식 앱 옆에 함께 띄우는
    /// 개발용 앱(`PPB_APP_VARIANT=dev ./scripts/build-app.sh`)은 Info.plist 의 `PPBDataName` 으로
    /// 다른 이름을 받는다. 같은 이름을 쓰면 세이브를 번갈아 덮어쓰고, 서로의 실행 표시를 보고
    /// 지난 실행이 비정상 종료됐다고 오해한다.
    static let dataName: String = {
        let name = Bundle.main.object(forInfoDictionaryKey: "PPBDataName") as? String ?? ""
        return name.isEmpty ? "PokePackBar" : name
    }()

    /// Application Support 아래 이 앱의 폴더.
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(dataName, isDirectory: true)
    }

    static var canUseNotifications: Bool {
        guard isBundledApp, let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}
