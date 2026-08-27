import Foundation

/// 이 앱의 정체성 — 저장소, 배포 이름, 연락처.
///
/// 한 곳에 모아 둔다. 포크한 뒤 여기저기 흩어진 원본 저장소 주소와 연락처를 하나씩
/// 찾아 고치다 보면 반드시 하나가 남고, 남은 하나는 테스터의 버그 리포트를 모르는 사람에게
/// 보내거나 남의 앱 릴리스를 권한다.
///
/// 값이 정해지지 않은 항목은 nil 로 둔다. 화면은 그 링크를 감추고, 업데이트 확인은 쉰다 —
/// 잘못된 곳을 가리키는 것보다 없는 편이 낫다.
enum AppLinks {

    /// GitHub 저장소 `소유자/이름`. 릴리스 확인과 설정의 저장소 링크가 이 값을 쓴다.
    static let githubRepo: String? = "wonyangs/PokePackBar"

    /// Homebrew cask 이름. tap 에 등록한 파일 이름과 같아야 한다.
    static let brewCask = "poke-pack-bar"

    /// Homebrew tap `소유자/homebrew-<이름>` 에서 tap 지정에 쓰는 짧은 형태.
    static let brewTap: String? = "wonyangs/tap"

    /// 문제 리포트 수신 주소. 없으면 설정에서 리포트 항목을 감춘다.
    /// 내부 배포라 별도 창구를 두지 않는다 — 제보는 저장소 이슈로 받는다.
    static let supportEmail: String? = nil

    // MARK: 파생

    static var githubURL: URL? {
        guard let githubRepo else { return nil }
        return URL(string: "https://github.com/\(githubRepo)")
    }

    static var latestReleaseAPI: URL? {
        guard let githubRepo else { return nil }
        return URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")
    }

    /// 업데이트 확인이 가능한 상태인가. 저장소가 정해져야 켜진다.
    static var updatesConfigured: Bool { githubRepo != nil }
}
