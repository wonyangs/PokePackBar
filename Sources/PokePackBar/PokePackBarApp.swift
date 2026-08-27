import AppKit
import QuartzCore
import SwiftUI

@main
@MainActor
struct PokePackBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바는 AppDelegate 의 NSStatusItem 이 담당.
        // MenuBarExtra 라벨은 고빈도 갱신 시 재렌더링 폭주로 CPU/메모리 문제가 있어 사용하지 않는다.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var outsideClickMonitor = OutsideClickMonitor()
    private var store: UsageStore!
    private var wallet: WalletStore!
    private var updater: UpdateChecker!
    private let navigation = PopoverNavigation()


    func applicationDidFinishLaunching(_ notification: Notification) {
        // 조립된 .app 이 리소스를 실제로 여는지 확인하고 끝내는 모드. build-app.sh 가 쓴다.
        //
        // 파일이 있는지 스크립트가 확인하는 것만으로는 부족하다. 앱이 보는 위치와
        // 스크립트가 검사하는 위치가 어긋나면 둘 다 통과하고 배포된 뒤에만 죽는다 —
        // 실제로 그렇게 나갔다. 앱에게 직접 물어보는 것만이 그 어긋남을 잡는다.
        if CommandLine.arguments.contains("--verify-resources") {
            if let problem = AppResources.verify() {
                FileHandle.standardError.write(Data("리소스 확인 실패: \(problem)\n".utf8))
                exit(1)
            }
            print("리소스 확인 통과: \(AppResources.bundle?.bundlePath ?? "?")")
            exit(0)
        }

        // 로그인 에이전트 등록(plist 의 RunAtLoad)이 이미 떠 있는 앱을 한 번 더 실행한다 — 나중에 뜬
        // 쪽이 물러난다. 메뉴바 항목을 만들기 전에 판정해 아이콘이 떴다 사라지는 깜빡임을 없애고,
        // **`CrashReporter.install` 보다도 앞**에 둔다: 뒤면 물러나는 인스턴스가 running 마커를 덮어쓰고
        // 종료 시 `markClean()` 이 발화해, 살아남은 쪽이 나중에 크래시해도 다음 실행이 정상 종료로 읽는다.
        if SingleInstance.shouldYieldToRunningInstance() {
            // writeAndFlush: write is async and terminate reaches exit(0) in
            // the same turn. Without the drain this line is lost (42 of 100
            // in the #163 review) and a false positive looks like a crash.
            AppLog.writeAndFlush("duplicate instance: yielding to the instance already running")
            NSApp.terminate(nil)
            return
        }
        // 서브프로세스(codex app-server 등) 파이프가 조기 종료로 끊겨도 SIGPIPE 로 앱이 죽지 않게
        // 무시한다. ProcessRunner 의 throwing write 와 함께 broken-pipe 크래시를 막는 이중 방어.
        signal(SIGPIPE, SIG_IGN)
        // 크래시·OOM·강제종료·런치실패를 로그에 남기는 전역 처리. 가능한 이르게(초기 크래시도 잡히게).
        CrashReporter.install(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
        NSApp.setActivationPolicy(.accessory)
        Self.migrateLegacyStorageIfNeeded()   // TokenMac → PokePackBar 리네임: 기존 companion/캐시 보존
        LoginItem.migrateFromLegacyLoginItemIfNeeded()   // 로그인아이템 → KeepAlive 에이전트(크래시 자동 재실행)
        store = UsageStore()
        wallet = WalletStore()
        updater = UpdateChecker()
        store.localizationLanguage = wallet.language   // 알림 현지화용 미러 시드
        store.onRefresh = { [weak self] in self?.onStoreRefreshed() }   // 한도 로드 후 companion·사탕 지급
        Task { await updater.check() }                    // 기동 시 1회 업데이트 확인

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            setStatusImage(Self.menuIcon())
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.cell?.usesSingleLineMode = false   // 사용량/한도를 2줄로 세로 스택 가능하게
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        popover.delegate = self   // didShow: outside-click monitor; didClose: 호스팅 해제 + 모니터 제거

        observeStore()
        applyState()
    }

    /// Observation 기반 상태 반영 — store 의 menuTitle(=menuLines) 변경 시 재호출.
    /// (isStale 은 더 이상 추적 안 함 — 메뉴바 dim 제거로 시각 출력에 관여하지 않음.)
    private func observeStore() {
        withObservationTracking {
            _ = store.menuTitle
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyState()
                self.observeStore()
            }
        }
    }


    private func applyState() {
        guard let button = statusItem.button else { return }
        Self.applyMenuText(store.menuLines, to: button)
        // stale 시각 dim 제거 — 슬립/런치 직후 refresh 완료 전 몇 초간 회색으로 보여 '고장/비활성'
        // 으로 오인되던 것 방지(사용자 반복 지적). 데이터가 오래됐다는 신호가 필요하면 팝오버
        // (limitsUpdatedAt 등)에서 제공하고, 메뉴바 아이콘·숫자는 흐리게 하지 않는다.
        button.appearsDisabled = false

        updateWallet()
    }

    /// 메뉴바 버튼 텍스트 반영 — 1줄이면 기본 title(13pt), 2줄 이상이면 세로 스택.
    /// 줄 수에 맞춰 폰트를 자동 축소해 N줄이 메뉴바 높이에 클리핑 없이 들어오게 한다. 색을 지정하지
    /// 않아 메뉴바 명암(라이트/다크)·비활성(appearsDisabled) 상태에 자동 적응한다.
    private static func applyMenuText(_ lines: [String], to button: NSStatusBarButton) {
        if lines.count >= 2 {
            // NSStatusBarButton 은 멀티라인 title 을 세로 중앙에 두지 않고 위로 치우쳐 그린다(측정:
            // titleRect.y 가 음수 → 상단 클리핑 + 하단 여백, 사용자 지적). 그래서 baselineOffset 을
            // '런타임 측정'으로 보정한다: offset 0 으로 한번 세팅해 셀이 계산한 title 상자(titleRect)를
            // 재고, 그 상자 중앙을 버튼 중앙에 맞추는 offset 을 역산해 재적용. 매직넘버 없이 두께·폰트·
            // 아이콘에 자동 적응. 줄높이는 폰트 자연 줄높이(×1.16)보다 크게 둬 어센더 클리핑을 막는다.
            let thickness = NSStatusBar.system.thickness
            let share = thickness / CGFloat(lines.count)                 // 줄당 몫
            let fontSize = min(11, max(8, (share * 0.85).rounded(.down)))
            let effLH = min(share, (fontSize * 1.28).rounded())          // 자연 줄높이보다 크게(어센더 클리핑 방지)
            let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
            func titled(_ offset: CGFloat) -> NSAttributedString {
                let para = NSMutableParagraphStyle()
                para.alignment = .center
                para.minimumLineHeight = effLH
                para.maximumLineHeight = effLH
                return NSAttributedString(
                    string: lines.joined(separator: "\n"),
                    attributes: [.font: font, .paragraphStyle: para, .baselineOffset: offset])
            }
            let bounds = button.bounds
            if bounds.height > 1 {
                // 1) offset 0 으로 측정 → 2) 상자 중앙을 버튼 중앙에 맞추는 보정량 역산 → 3) 재적용.
                // (측정용 title 은 표시 전 즉시 교체되므로 깜빡임 없음.)
                button.attributedTitle = titled(0)
                let r0 = (button.cell as? NSButtonCell)?.titleRect(forBounds: bounds) ?? bounds
                button.attributedTitle = titled(r0.midY - bounds.midY)
            } else {
                button.attributedTitle = titled(0)   // 레이아웃 전(폭 0) — 보정 없이, 다음 갱신에 재보정
            }
        } else {
            // 1줄로 되돌릴 때 이전 attributedTitle 이 남지 않게 먼저 비운다.
            button.attributedTitle = NSAttributedString(string: "")
            let title = lines.first ?? ""
            button.title = title.isEmpty ? "" : " " + title
        }
    }

    /// UsageStore 값 → CompanionStore (사용량 적립 + 표시 상태). 매 관찰 변경 시 호출.
    private func updateWallet() {
        wallet.update(
            todayTokensByProvider: store.todayTokensByProvider,
            todayDate: LocalUsageReader.todayKey(),
            hasUsageData: store.hasUsageData)
    }

    /// 매 refresh 완료 훅 — companion 갱신 + 사탕 지급(한도가 신선한 시점). 지급을 여기 묶는 이유는
    /// UsageStore.onRefresh 주석 참조(observeStore 만으론 한도 변경이 companion 에 안 전달되는 케이스).
    private func onStoreRefreshed() {
        updateWallet()
        // 한도가 신선한 시점에 지급을 묶는다. 사용량 관찰만으로는 한도 변경이 전달되지 않는
        // 경로가 있다(UsageStore.onRefresh 주석 참조).
        wallet.grantBonusPacks(from: store.bonusEligibleWindows,
                               limitsReady: store.limitsReady,
                               availableSets: Self.packSetIDs)
    }

    /// 보너스 팩으로 줄 수 있는 세트. 카드 목록은 번들 리소스라 한 번만 읽는다.
    private static let packSetIDs: [String] = CardIndex.loadBundled()?.setIDs ?? []

    // MARK: 메뉴바 애니메이션



    private var lastStatusImage: NSImage?

    /// 상태아이템 이미지 교체. ① **diff-gate**: 같은 이미지 재대입이면 스킵 — 레이어 dirty → CA 커밋 →
    /// WindowServer 디스플레이 사이클 왕복(= idle wakeup)을 제거한다(배터리). 단일프레임 스프라이트·중복
    /// advanceMenu 패스에서 같은 프레임을 반복 대입하던 것을 걸러낸다(애니메이션 프레임은 서로 다른 객체라
    /// 정상 통과). ② **암묵적 CA 전환 억제**: 레이어 백드 NSStatusBarButton 은 대입마다 NSStatusItemScene
    /// 전환 애니메이션을 돌려 상태바를 재합성한다(측정: idle CPU 주범) → setDisableActions 로 전환 없이 즉시 반영.
    private func setStatusImage(_ image: NSImage?) {
        guard image !== lastStatusImage else { return }
        lastStatusImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        statusItem.button?.image = image
        CATransaction.commit()
    }



    // MARK: 프레임 합성 (22px)





    /// TokenMac→PokePackBar 리네임에 따른 1회 이전: 기존 Application Support 폴더를
    /// 새 이름으로 옮겨 companion 진행상황·스프라이트 캐시·스냅샷을 보존한다(신규 폴더 없을 때만).
    private static func migrateLegacyStorageIfNeeded() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = base.appendingPathComponent("TokenMac")
        let new = base.appendingPathComponent("PokePackBar")
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return }
        try? fm.moveItem(at: old, to: new)
    }


    /// 팝오버 콘텐츠(SwiftUI 호스팅) 생성. .transient 팝오버는 contentViewController 를 평생 보유해 닫혀도
    /// NSHostingView 트리가 상주하며 매 디스플레이 사이클 재레이아웃된다(측정: idle CPU 최대 비용 — 닫힌
    /// 팝오버의 relative-time Text self-invalidation × 메뉴 애니메이션 CA 커밋). 그래서 열 때 만들고 닫힐 때 해제.
    func openPopover() {
        // Pet click is an outside click for a .transient popover — if already shown it is
        // already dismissing; the old "activate/makeKey" branch never applied.
        guard !popover.isShown else { return }
        togglePopover()
    }

    /// 메뉴바 아이콘. 스프라이트를 걷어낸 자리에 카드 묶음 기호를 쓴다 —
    /// 템플릿 이미지라 라이트·다크 메뉴바에 자동으로 맞는다.
    private static func menuIcon() -> NSImage? {
        let image = NSImage(systemSymbolName: "rectangle.stack.fill",
                            accessibilityDescription: "PokePackBar")
        image?.isTemplate = true
        return image
    }

    private func buildPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environment(store).environment(wallet).environment(updater).environment(navigation))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)   // 해제·메뉴 애니메이션 재개는 popoverDidClose 에서
        } else {
            navigation.reset()   // 닫혔다 열리면 항상 Home 으로 (설정 화면 잔류 방지)
            buildPopoverContent()   // 열 때 호스팅 트리 생성(닫힐 때 해제)
            // LSUIElement 앱이 비활성이면 팝오버 내부 버튼 클릭이 무시됨 — show 전에 활성화 보장
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            store.requestNotificationAuthorizationIfNeeded()   // 알림 권한은 사용자가 앱을 처음 열 때 요청
            Task { await updater.check() }   // 팝오버 열 때 재확인(내부 minInterval 디바운스)
        }
    }

    /// Start and stop are both delegate-driven so a second `show` path cannot
    /// overwrite a live token (#168). `start` is also idempotent if `didShow` fires twice.
    func popoverDidShow(_ notification: Notification) {
        startOutsideClickMonitor()
    }

    /// 팝오버가 닫히면 호스팅 컨트롤러를 해제한다 — 숨은 트리의 재레이아웃 비용을 없앤다.
    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        popover.contentViewController = nil
    }

    /// 다른 메뉴바 팝업은 앱을 비활성화 안 시켜 .transient 가 못 닫는다 → 열림 동안만 앱 밖 클릭을 직접 감지해 닫는다(관찰 전용, 권한 불필요).
    private func startOutsideClickMonitor() {
        outsideClickMonitor.start {
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.popover.isShown else { return }
                    self.popover.performClose(nil)
                }
            }
        }
    }

    private func stopOutsideClickMonitor() {
        outsideClickMonitor.stop { NSEvent.removeMonitor($0) }
    }

}
