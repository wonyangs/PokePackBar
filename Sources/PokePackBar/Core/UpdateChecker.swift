import AppKit
import Observation

/// GitHub 릴리스 최신 버전을 확인해 새 버전이 있으면 팝오버에 알린다.
/// 실제 설치는 brew 사용자면 `brew upgrade`, 그 외엔 릴리스 페이지 열기(저위험·인프라 0).
@MainActor
@Observable
final class UpdateChecker {
    struct Available: Equatable { let version: String; let url: String }

    private(set) var available: Available?
    private(set) var isUpdating = false

    let currentVersion: String
    private var repo: String? { AppLinks.githubRepo }
    private let clock: () -> Date
    private var lastChecked: Date?

    /// 릴리스 조회. 테스트가 실패를 재현할 수 있게 주입받는다 —
    /// 실패했을 때 잠금이 걸리는지가 이 클래스에서 가장 잘 틀리는 부분이다.
    private let fetch: (URLRequest) async -> (Data, URLResponse)?

    init(currentVersion: String? = nil, clock: @escaping () -> Date = Date.init,
         fetch: @escaping (URLRequest) async -> (Data, URLResponse)? = {
             try? await URLSession.shared.data(for: $0)
         }) {
        self.currentVersion = currentVersion
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        self.clock = clock
        self.fetch = fetch
    }

    /// 조회 간격(초). 팝오버를 열 때 이보다 오래됐으면 다시 확인한다.
    ///
    /// GitHub REST API 는 **인증 없이 IP 당 시간당 60회**다. 1분 간격이 그 한도와 정확히
    /// 같아 여유가 0 이므로 5분으로 둔다 — 최악에도 시간당 12회라 한도의 20% 만 쓴다.
    /// 여유가 필요한 이유는 같은 IP 를 쓰는 다른 것들 때문이다. 공유 회선이나 사무실 NAT
    /// 뒤에서는 60회를 한 사람이 다 쓰지 않는다. 한도를 넘기면 403 이 돌아오고 그 시간 동안
    /// 업데이트 확인이 통째로 죽는다 — 자주 확인하려다 아예 못 하게 된다.
    ///
    /// 조건부 요청(ETag)으로 아끼는 방법은 **인증한 요청에만** 적용돼서 토큰이 없는 앱에는
    /// 소용이 없다(304 도 한도를 깎는다).
    ///
    /// 배경 타이머는 두지 않는다. 업데이트 배지는 팝오버 안에만 있어서 닫혀 있는 동안 조회해도
    /// 보여 줄 곳이 없고, 상시 네트워크 깨우기는 메뉴바 앱의 idle 규율과도 어긋난다.
    nonisolated static let minimumCheckInterval: TimeInterval = 300

    /// GitHub 무인증 한도가 정하는 절대 하한(초). 이보다 짧으면 403 을 맞는다.
    nonisolated static let rateLimitFloor: TimeInterval = 60

    /// 최신 릴리스 조회 → 새 버전이고 사용자가 그 버전을 'skip' 하지 않았으면 available 설정.
    /// minInterval 보다 자주 호출되면 무시(레이트리밋 보호).
    func check(minInterval: TimeInterval = UpdateChecker.minimumCheckInterval) async {
        // 저장소가 정해지기 전에는 확인하지 않는다. 켜 두면 없는 곳에 30분마다 요청만 나가고,
        // 실패해도 조용히 no-op 이라 증상이 드러나지 않는다.
        guard AppLinks.updatesConfigured else { return }
        if let last = lastChecked, clock().timeIntervalSince(last) < minInterval { return }
        guard let url = AppLinks.latestReleaseAPI else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = await fetch(req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String,
              // 응답 필드가 NSWorkspace.open 으로 가므로 https + github.com 만 허용(스킴 하이재킹 방지)
              let htmlURL = URL(string: html), htmlURL.scheme == "https", htmlURL.host == "github.com"
        else { return }

        // **성공했을 때만** 시각을 기록한다. 요청 전에 찍으면 실패한 확인도 30분 잠금을 걸어,
        // 기동 직후 네트워크가 아직 안 올라온 한 번의 실패로 그 뒤 팝오버를 열어도 30분간
        // 아무 일이 없다. 테스터가 메인 화면에 업데이트가 안 뜬다고 보고한 것이 이 경로다
        // (설정의 수동 확인은 minInterval 0 이라 잠금을 지나쳐 그때만 떴다).
        lastChecked = clock()

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let skipped = UserDefaults.standard.string(forKey: "skippedUpdateVersion")
        if Self.isNewer(latest, than: currentVersion), latest != skipped {
            available = Available(version: latest, url: html)
        } else {
            available = nil
        }
    }

    /// 이 버전은 다시 알리지 않음.
    func skipCurrent() {
        if let v = available?.version { UserDefaults.standard.set(v, forKey: "skippedUpdateVersion") }
        available = nil
    }

    /// 업데이트 적용: brew cask 설치본이면 `brew upgrade` 후 재시작, 아니면 릴리스 페이지.
    func applyUpdate() {
        guard let update = available, !isUpdating else { return }
        isUpdating = true
        Task { @MainActor in
            // brew cask 설치본이면 분리(detached) 스크립트가 앱 종료 후 tap 갱신→업그레이드→재오픈.
            // 그 외(brew 미설치/비-cask 설치)면 릴리스 페이지를 연다.
            let brew = await Task.detached { Self.brewCaskPath() }.value
            if let brew {
                Self.launchDetachedUpgrade(brew: brew)
                NSApp.terminate(nil)
            } else {
                isUpdating = false
                AppLog.write("update: brew cask 아님/brew 미설치 → 릴리스 페이지 열기")
                if let u = URL(string: update.url) { NSWorkspace.shared.open(u) }
            }
        }
    }

    // MARK: 버전 비교

    /// a 가 b 보다 높은 semver 인가. ("2.0.10" > "2.0.9" 등 숫자 비교)
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: brew 적용 (nonisolated — 블로킹 Process 는 detached 에서)

    /// 우리 cask 로 설치돼 있으면 brew 경로 반환, 아니면 nil(→ 릴리스 페이지 폴백).
    private nonisolated static func brewCaskPath() -> String? {
        guard let brew = BinaryLocator.resolve("brew", staticPaths: [
            "/opt/homebrew/bin/brew", "/usr/local/bin/brew",
        ]) else { return nil }
        return run(brew, ["list", "--cask", AppLinks.brewCask], timeout: 20) ? brew : nil
    }

    private nonisolated static func run(_ binary: String, _ args: [String], timeout: TimeInterval) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate(); return false }
        return process.terminationStatus == 0
    }

    /// 앱이 완전히 종료된 뒤 tap 갱신 + cask 업그레이드 + 재오픈을 수행하는 분리(detached) 스크립트 본문.
    /// - `brew update` 선행: auto-update 빈도 제한(기본 24h)으로 stale 한 로컬 tap 때문에 `brew upgrade`
    ///   가 no-op(exit 0) 되어 "업데이트 안 됨 + 앱만 종료"가 나던 문제를 막는다.
    /// - 앱 종료를 기다림(`kill -0 $3`): 실행 중 번들 교체 레이스 + 재오픈 LaunchServices(-600) 레이스 회피.
    ///   `pgrep -x` 대신 특정 PID를 감시하여 중복 인스턴스가 실행 중일 때도 20s 타임아웃 없이 즉시 진행 (#175).
    /// - brew 를 백그라운드+워치독(≤300s)으로 감싸 hang 시에도 reopen 이 반드시 실행되게 함
    ///   (앱이 종료된 채 영영 안 돌아오는 것 방지). 종료 직후 재오픈 실패 대비 `open` 재시도.
    /// 인자는 positional($1=brew, $2=bundlePath, $3=pid)로 전달 — 셸 인젝션 차단.
    /// cask 이름은 아직 존재하지 않는다. `releasesPublished` 를 켜기 전에
    /// 실제로 등록한 cask 이름으로 맞춰야 한다 — 틀리면 다른 앱을 업그레이드한다.
    nonisolated static let detachedUpgradeScript = """
    for i in $(seq 1 40); do kill -0 "$3" 2>/dev/null || break; sleep 0.5; done
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    ( "$1" update; "$1" upgrade --cask poke-pack-bar ) &
    brew_pid=$!
    for i in $(seq 1 300); do kill -0 "$brew_pid" 2>/dev/null || break; sleep 1; done
    kill "$brew_pid" 2>/dev/null
    # open 을 먼저 쓴다. launchctl kickstart 는 에이전트가 등록만 돼 있으면 앱을 띄우지
    # 않고도 0 을 돌려주므로, 그걸 먼저 시도하고 성공으로 보면 앱이 영영 안 뜬다.
    # open 은 .app 을 실제로 띄웠을 때만 0 이다.
    #
    # 결과 확인에 pgrep 을 쓰지 않는다 — 이름으로 찾으면 다른 인스턴스에 걸린다(#175).
    #
    # 경로가 비면 open 은 현재 디렉터리를 Finder 로 연다. 앱 대신 창만 뜨는 일이 없게 막는다.
    if [ -d "$2" ]; then
      for i in $(seq 1 20); do
        open "$2" 2>/dev/null && break
        launchctl kickstart -k "gui/$(id -u)/\(LoginItem.label)" 2>/dev/null
        sleep 1
      done
    fi
    """

    nonisolated static func launchDetachedUpgrade(
        brew: String,
        pid: pid_t = ProcessInfo.processInfo.processIdentifier,
        bundlePath: String = Bundle.main.bundlePath
    ) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", detachedUpgradeScript, "sh", brew, bundlePath, String(pid)]
        try? task.run()
    }
}
