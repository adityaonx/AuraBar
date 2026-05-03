import AppKit
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var permissionWindow: NSWindow?
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "AuraBar")
            button.action = #selector(togglePopover)
            button.target = self
        }

        DispatchQueue.main.async {
            self.setupPopover()
            AuraEngine.shared.start()
        }

        NotificationCenter.default.addObserver(
            forName: .requestScreenCaptureForDynamic,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.showPermissionWindow() }

        // Settings button in the tray posts this — we open a proper window
        // so clicking outside it still dismisses the popover normally.
        NotificationCenter.default.addObserver(
            forName: .openSettingsWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.showSettingsWindow() }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 430)
        popover.behavior = .transient          // clicks outside dismiss it
        popover.contentViewController = NSHostingController(rootView: MainDashboardView())
    }

    @objc func togglePopover() {
        guard popover != nil else { return }
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if button.window == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.showPopover() }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Settings window
    // Opened as a standalone NSWindow so the popover's .transient behaviour
    // is not blocked — clicking anywhere outside the settings window still
    // dismisses the tray popover as expected.

    func showSettingsWindow() {
        // Close the tray popover first so it doesn't sit behind the window
        if popover.isShown { popover.performClose(nil) }

        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = "AuraBar Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating           // stays above other windows
        window.setContentSize(NSSize(width: 460, height: 420))
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Permission window

    func showPermissionWindow() {
        if popover.isShown { popover.performClose(nil) }

        if let existing = permissionWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let sheet = ScreenCapturePermissionSheet(onDismiss: {
            [weak self] in self?.dismissPermissionWindow()
        })
        let hosting = NSHostingController(rootView: sheet)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .normal
        window.setContentSize(NSSize(width: 420, height: 500))
        window.center()
        window.isReleasedWhenClosed = false

        permissionWindow = window
        window.makeKeyAndOrderFront(nil as AnyObject?)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissPermissionWindow() {
        permissionWindow?.close()
        permissionWindow = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showPopover()
            AuraEngine.shared.forceUpdate()
        }
    }
}
