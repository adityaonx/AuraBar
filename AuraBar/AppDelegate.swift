import AppKit
import QuartzCore
import UniformTypeIdentifiers
import ServiceManagement

// MARK: - Core Aura View
class AuraView: NSView {
    var auraColor: NSColor = .black {
        didSet { self.needsDisplay = true }
    }
    override func draw(_ dirtyRect: NSRect) {
        auraColor.setFill()
        dirtyRect.fill()
    }
}

// MARK: - Main Application Controller
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var windowMap: [NSScreen: NSPanel] = [:]
    var viewMap: [NSPanel: AuraView] = [:]
    
    var settingsWindow: SettingsWindow?
    var statusItem: NSStatusItem?
    
    let developerName = "Aditya Sahu"
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        
        // FIX: async call to break initial layout recursion logs
        DispatchQueue.main.async {
            self.setupOverlay()
            if let currentApp = NSWorkspace.shared.frontmostApplication {
                self.updateAura(for: currentApp)
            }
        }
        
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showSettings(nil)
        }

        // Observer: App activation
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.updateAura(for: app)
            }
        }
        
        // Observer: Space change (Exiting/Entering Full Screen)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // FIX: Slight delay to allow macOS to finish the "swipe" animation
            // and update screen.visibleFrame before we check.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if let currentApp = NSWorkspace.shared.frontmostApplication {
                    self?.updateAura(for: currentApp)
                }
            }
        }
        
        // Observer: Monitor/Resolution changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.setupOverlay() }
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "AuraBar")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit AuraBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func setupOverlay() {
        let activeScreens = NSScreen.screens
        
        windowMap.keys.forEach { screen in
            if !activeScreens.contains(screen) {
                windowMap[screen]?.close()
                windowMap.removeValue(forKey: screen)
            }
        }

        for screen in activeScreens {
            let barHeight = screen.frame.maxY - screen.visibleFrame.maxY
            guard barHeight > 0 else { continue }

            let frame = NSRect(x: screen.frame.origin.x - 100,
                               y: screen.frame.maxY - barHeight,
                               width: screen.frame.width + 200,
                               height: barHeight)

            if let existingPanel = windowMap[screen] {
                // Only update if frame actually changes to avoid layout recursion
                if existingPanel.frame != frame {
                    existingPanel.setFrame(frame, display: true)
                }
            } else {
                let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) - 1)
                panel.backgroundColor = .clear
                panel.ignoresMouseEvents = true
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

                let view = AuraView(frame: panel.contentView!.bounds)
                view.autoresizingMask = [.width, .height]
                panel.contentView?.addSubview(view)
                
                windowMap[screen] = panel
                viewMap[panel] = view
                panel.orderFrontRegardless()
            }
        }
    }

    // SURGICAL FIX: Sandbox-Safe Full-Screen detection
    private func isScreenInFullScreen(screen: NSScreen, app: NSRunningApplication) -> Bool {
        // Condition 1: Menu bar is hidden (Typical Full Screen)
        if screen.frame.size == screen.visibleFrame.size { return true }
        
        // Condition 2: Check if app window covers the bar (Xcode/Exclusive mode)
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windowList {
            let pid = window[kCGWindowOwnerPID as String] as? Int32
            let layer = window[kCGWindowLayer as String] as? Int
            
            if pid == app.processIdentifier && layer == 0 {
                if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                   let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                    
                    // If the window is focused on this screen and covers the menu bar area
                    if bounds.intersects(screen.frame) && bounds.width >= screen.frame.width - 5 && bounds.height > screen.visibleFrame.height + 5 {
                        return true
                    }
                }
            }
        }
        return false
    }

    func updateAura(for app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier?.lowercased() ?? ""
        let mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]

        for (screen, panel) in windowMap {
            guard let view = viewMap[panel] else { continue }
            
            // Check if bar should hide
            if isScreenInFullScreen(screen: screen, app: app) || bundleID.contains("finder") {
                view.auraColor = .clear
                continue
            }

            // Resume color automatically
            if let rgba = mappings[bundleID] {
                view.auraColor = NSColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
            } else {
                // Default fallback tint
                view.auraColor = NSColor(white: 0.05, alpha: 0.8)
            }
        }
    }

    // MARK: - Standard Actions
    @objc func checkUpdates() {
        let urlString = "https://raw.githubusercontent.com/adityaonx/AuraBar/main/version.json"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let remoteVersion = json["version"] as? String else { return }
            let localVersion = self?.appVersion ?? "1.0.0"
            DispatchQueue.main.async {
                if remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending {
                    self?.showNewVersionAvailable(version: remoteVersion)
                }
            }
        }.resume()
    }

    func showNewVersionAvailable(version: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available!"; alert.informativeText = "AuraBar v\(version) is available."
        alert.addButton(withTitle: "Download"); alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/adityaonx/AuraBar/releases/latest") { NSWorkspace.shared.open(url) }
        }
    }

    @objc func toggleLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            try? (service.status == .enabled ? service.unregister() : service.register())
        }
    }

    @objc func showAbout() {
        let alert = NSAlert(); alert.messageText = "AuraBar \(appVersion)"; alert.runModal()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil { settingsWindow = SettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Settings Window Logic
class SettingsWindow: NSWindow {
    let mainStack = NSStackView()
    let listStack = NSStackView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 450),
                   styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        self.title = "AuraBar Settings"; self.isReleasedWhenClosed = false
        let content = NSView(); self.contentView = content
        mainStack.orientation = .vertical; mainStack.alignment = .centerX; mainStack.spacing = 15
        mainStack.edgeInsets = NSEdgeInsets(top: 25, left: 20, bottom: 25, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        let header = NSTextField(labelWithString: "App Color Mappings")
        header.font = NSFont.boldSystemFont(ofSize: 13); mainStack.addArrangedSubview(header)
        let addButton = NSButton(title: "＋ Add Application", target: self, action: #selector(addApp))
        addButton.bezelStyle = .rounded; mainStack.addArrangedSubview(addButton)
        listStack.orientation = .vertical; listStack.spacing = 12; listStack.alignment = .leading
        mainStack.addArrangedSubview(listStack); loadExisting()
    }

    @objc func addApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            let bundleID = Bundle(url: url)?.bundleIdentifier?.lowercased() ?? "unknown"
            createRow(bundleID: bundleID, color: .gray); saveColor(bundleID: bundleID, color: .gray)
        }
    }

    func createRow(bundleID: String, color: NSColor) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 10
        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        well.color = color; well.identifier = NSUserInterfaceItemIdentifier(bundleID)
        well.target = self; well.action = #selector(colorChanged(_:))
        let name = bundleID.replacingOccurrences(of: "com.", with: "").capitalized
        let label = NSTextField(labelWithString: name); label.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let removeBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")!, target: self, action: #selector(removeApp(_:)))
        removeBtn.identifier = NSUserInterfaceItemIdentifier(bundleID); removeBtn.isBordered = false
        row.addArrangedSubview(well); row.addArrangedSubview(label); row.addArrangedSubview(removeBtn)
        listStack.addArrangedSubview(row)
    }

    @objc func colorChanged(_ sender: NSColorWell) {
        guard let bundleID = sender.identifier?.rawValue else { return }
        saveColor(bundleID: bundleID, color: sender.color); updateAuraBar()
    }

    @objc func removeApp(_ sender: NSButton) {
        guard let bundleID = sender.identifier?.rawValue else { return }
        var mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
        mappings.removeValue(forKey: bundleID)
        UserDefaults.standard.set(mappings, forKey: "AuraMappings")
        listStack.arrangedSubviews.forEach { view in
            if let stack = view as? NSStackView, stack.arrangedSubviews.contains(where: { $0.identifier?.rawValue == bundleID }) {
                stack.removeFromSuperview()
            }
        }; updateAuraBar()
    }

    func saveColor(bundleID: String, color: NSColor) {
        if let sRGB = color.usingColorSpace(.sRGB) {
            var mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
            mappings[bundleID] = [sRGB.redComponent, sRGB.greenComponent, sRGB.blueComponent, sRGB.alphaComponent]
            UserDefaults.standard.set(mappings, forKey: "AuraMappings")
        }
    }

    func updateAuraBar() {
        if let app = NSWorkspace.shared.frontmostApplication { (NSApplication.shared.delegate as? AppDelegate)?.updateAura(for: app) }
    }

    func loadExisting() {
        let mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
        for (id, rgba) in mappings { createRow(bundleID: id, color: NSColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])) }
    }
}
