import SwiftUI

@main
struct AuraBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    // Made internal (not private) so ScreenCapturePermissionSheet can call showPopover after grant
    var menuBarController: MenuBarController?
    var onboardingWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.windows.forEach { $0.close() }

        if PermissionManager.shared.isAccessibilityGranted {
            launchTrayApp()
        } else {
            showOnboarding()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func launchTrayApp() {
        if menuBarController == nil {
            menuBarController = MenuBarController()
        }
        NSApp.setActivationPolicy(.accessory)
        onboardingWindow?.close()
        onboardingWindow = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.menuBarController?.showPopover()
        }
        // Check for updates 2s after launch so the app is fully settled first
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkOnLaunch()
        }
    }

    func showOnboarding() {
        NSApp.setActivationPolicy(.regular)

        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.isReleasedWhenClosed     = false
        window.titleVisibility          = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor          = .clear
        window.isOpaque                 = false
        window.hasShadow                = true
        window.level                    = .normal

        window.contentView = NSHostingView(rootView: OnboardingView())
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
