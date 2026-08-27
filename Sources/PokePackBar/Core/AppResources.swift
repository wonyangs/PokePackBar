import Foundation

/// 번들 리소스(카드 목록, 팩 아트)를 찾는다.
///
/// `Bundle.module` 을 쓰지 않는다. SwiftPM 이 만들어 주는 그 접근자는 두 가지 이유로
/// 앱에 부적합하다.
///
/// 첫째, **찾지 못하면 `fatalError` 로 죽는다.** 리소스가 없으면 화면이 비는 정도로
/// 끝나야지 앱이 사라지면 안 된다.
///
/// 둘째, **찾는 위치가 `.app` 배치와 맞지 않는다.** 접근자는 `Bundle.main.bundleURL`
/// 바로 아래(= `PokePackBar.app/`)를 보는데, `.app` 의 리소스 자리는 관례상
/// `Contents/Resources/` 다. 폴백으로 빌드 기계의 `.build` 절대경로를 보기 때문에
/// 빌드한 컴퓨터에서는 통과하고 다른 컴퓨터에서만 죽는다 — 배포 전에 드러나지 않는
/// 종류의 결함이다(실제로 테스터에게서만 나왔다).
enum AppResources {

    /// SwiftPM 이 정하는 리소스 번들 이름. `<패키지>_<타깃>.bundle` 규칙이다.
    static let bundleName = "PokePackBar_PokePackBar.bundle"

    /// 리소스 번들. 찾지 못하면 nil 이다 — 절대 트랩하지 않는다.
    static let bundle: Bundle? = {
        for url in candidateURLs() {
            if let found = Bundle(url: url) { return found }
        }
        // 리소스를 평평하게 넣은 배치라면 메인 번들이 곧 리소스 번들이다.
        if Bundle.main.url(forResource: "card-index", withExtension: "json") != nil {
            return Bundle.main
        }
        AppLog.write("resource bundle not found in: \(candidateURLs().map(\.path).joined(separator: ", "))")
        return nil
    }()

    /// 찾아볼 위치. 순서가 곧 우선순위다 — 테스트가 이 순서를 고정한다.
    static func candidateURLs() -> [URL] {
        var urls: [URL] = []
        // `.app` 배치 — Contents/Resources 아래. build-app.sh 가 여기에 넣는다.
        if let resources = Bundle.main.resourceURL {
            urls.append(resources.appendingPathComponent(bundleName))
        }
        // SwiftPM 기본 배치 — 실행 파일과 나란히. `swift run` 과 테스트가 여기다.
        urls.append(Bundle.main.bundleURL.appendingPathComponent(bundleName))
        // 테스트 번들 기준 — xctest 는 메인 번들이 러너라 자기 옆을 봐야 한다.
        let here = Bundle(for: BundleMarker.self).bundleURL.deletingLastPathComponent()
        urls.append(here.appendingPathComponent(bundleName))
        return urls
    }

    /// 번들 위치를 잡기 위한 표식. 다른 용도는 없다.
    private final class BundleMarker {}

    /// 리소스가 실제로 열리는지 확인한다. 빌드 스크립트가 조립 직후 호출해
    /// 잘못된 위치에 넣은 채로 배포되는 것을 막는다.
    static func verify() -> String? {
        guard let bundle else { return "리소스 번들을 찾지 못했다" }
        guard bundle.url(forResource: "card-index", withExtension: "json") != nil else {
            return "번들은 찾았으나 card-index.json 이 없다: \(bundle.bundlePath)"
        }
        guard CardIndex.loadBundled() != nil else {
            return "card-index.json 을 읽지 못했다"
        }
        return nil
    }
}
