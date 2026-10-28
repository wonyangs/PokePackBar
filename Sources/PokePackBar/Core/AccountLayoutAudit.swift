import AppKit
import SwiftUI

@MainActor enum AccountLayoutAudit {
    static func run(output: URL) async throws {
        WindowPresentation.quiet = true
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: output.appendingPathComponent("fixture.json"))
        wallet.setLanguage(LayoutAuditOptions.language)
        LayoutAuditOptions.applyAppearance()
        OnlineText.wallet = wallet
        let suite = "ppb-account-layout-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "disableKeychainAccess")
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let updater = UpdateChecker(currentVersion: "0.0.0")
        var measurements: [[String: Any]] = []
        func capture(_ name: String, view: AnyView, size: NSSize) async throws {
            let controller = NSHostingController(rootView: view.background(Color(NSColor.windowBackgroundColor)))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = controller
            controller.view.setFrameSize(size)
            controller.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            controller.view.layoutSubtreeIfNeeded()
            guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
                throw LocalAudit.Failure(description: "Account layout capture failed")
            }
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw LocalAudit.Failure(description: "Account layout encoding failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            measurements.append(["screen": name, "width": size.width, "height": size.height,
                                 "minimumWidth": controller.view.fittingSize.width])
            window.close()
        }
        for section in SettingsView.SettingsTab.allCases {
            try await capture("settings-\(section.rawValue)", view: AnyView(SettingsView(onClose: {}, initialSection: section)
                .environment(usage).environment(wallet).environment(updater)),
                size: NSSize(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight))
        }
        for section in OnlineSettingsView.AccountTab.allCases {
            for width in [CGFloat(560), CGFloat(760)] {
                try await capture("account-\(section.rawValue)-\(Int(width))", view: AnyView(OnlineSettingsView(wallet: wallet,
                    auditSection: section, signedIn: section != .connection).padding(24)
                    .preferredColorScheme(width == 760 ? .light : .dark)), size: NSSize(width: width, height: 560))
            }
        }
        try await capture("account-import", view: AnyView(OnlineSettingsView(wallet: wallet, auditSection: .connection)
            .padding(24).preferredColorScheme(.light)), size: NSSize(width: 760, height: 800))
        try await capture("account-recover", view: AnyView(OnlineSettingsView(wallet: wallet, auditSection: .security).padding(24)),
                          size: NSSize(width: 560, height: 500))
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("measurements.json"))
        for _ in 0..<2 {
            AccountWindow.shared.show(wallet: wallet, auditing: true)
            try await Task.sleep(for: .milliseconds(100))
            guard let window = NSApp.windows.first(where: { $0.title == OnlineText.l.accountWindowTitle && $0.isVisible }) else {
                throw LocalAudit.Failure(description: "Account window did not reopen")
            }
            try LocalAudit.require(window.alphaValue == 0 && window.ignoresMouseEvents && !NSApp.isActive,
                                   "The audit put the account window on screen")
            window.close()
            try LocalAudit.require(window.contentView == nil, "Hidden account form retained")
        }
        print("PASS account layout: 4 compact settings sections, 12 native states including session import, light/dark, close/reopen and form disposal; isolated fixtures, no login")
    }
}

extension AccountLayoutAudit {
    /// 계정 창 레이아웃 검사용 기기 목록. 실제 사용처럼 긴 한국어 이름을 넣어 줄바꿈을 본다.
    static var fixtureDevices: [AccountDevice] {
        [AccountDevice(device_id: UUID().uuidString, name: "집에서 사용하는 MacBook Pro", last_login: 1_790_738_400, current: true),
         AccountDevice(device_id: UUID().uuidString, name: "여행용 Mac", last_login: nil, current: false)]
    }

    static var fixtureJobs: [AccountJob] {
        [AccountJob(name: "backup", state: "ok", last_success: 1_790_738_400, next_run: nil, error: nil),
         AccountJob(name: "prices", state: "failed", last_success: nil, next_run: nil,
                    error: "시세를 갱신하지 못했어요. 마지막 정상 가격을 유지하고 1시간 뒤에 다시 해요."),
         AccountJob(name: "expiry", state: "running", last_success: nil, next_run: nil, error: nil)]
    }
}
