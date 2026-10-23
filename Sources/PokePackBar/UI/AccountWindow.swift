import AppKit
import SwiftUI

@MainActor
final class AccountWindow: NSObject, NSWindowDelegate {
    static let shared = AccountWindow()
    private var window: NSWindow?

    func show(wallet: WalletStore, auditing: Bool = false, section: OnlineSettingsView.AccountTab? = nil) {
        OnlineText.wallet = wallet
        if let window {
            // 다른 탭을 열어 달라는 요청이면 그 탭으로 다시 그린다(예: 닉네임을 눌러 프로필로).
            if let section {
                window.contentView = NSHostingView(rootView: OnlineSettingsView(wallet: wallet, initialSection: section).padding(24))
            }
            WindowPresentation.present(window); return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = OnlineText.l.accountWindowTitle
        window.minSize = NSSize(width: 560, height: 500)
        window.contentView = NSHostingView(rootView: OnlineSettingsView(wallet: wallet, auditSection: auditing ? .connection : nil,
                                                                        initialSection: section ?? .connection).padding(24))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        WindowPresentation.present(window)
    }

    func windowWillClose(_ notification: Notification) {
        // Destroy form state rather than retain passwords/recovery codes in a hidden view.
        window?.contentView = nil
        window = nil
    }
}
