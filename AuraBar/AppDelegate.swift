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
    
    var window: NSPanel?
    var auraView: AuraView?
    var settingsWindow: SettingsWindow?
    var statusItem: NSStatusItem?
    
    let developerName = "Aditya Sahu"
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupOverlay()
        
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            updateAura(for: currentApp)
        }
        
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showSettings(nil)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.updateAura(for: app)
            }
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

    @objc func checkUpdates() {
        let urlString = "https://raw.githubusercontent.com/adityaonx/AuraBar/main/version.json"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.showUpdateAlert(title: "Connection Error", message: error.localizedDescription)
                return
            }

            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let remoteVersion = json["version"] as? String {
                    
                    let localVersion = self?.appVersion ?? "1.0.0"

                    DispatchQueue.main.async {
                        if remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending {
                            self?.showNewVersionAvailable(version: remoteVersion)
                        } else {
                            self?.showUpdateAlert(title: "Up to Date", message: "AuraBar v\(localVersion) is the newest version.")
                        }
                    }
                }
            } catch {
                self?.showUpdateAlert(title: "Parsing Error", message: "The update manifest is malformed.")
            }
        }.resume()
    }

    func showUpdateAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func showNewVersionAvailable(version: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available!"
        alert.informativeText = "AuraBar v\(version) is available. Download now?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/adityaonx/AuraBar/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func toggleLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            try? (service.status == .enabled ? service.unregister() : service.register())
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AuraBar \(appVersion)"
        alert.informativeText = "Developed by \(developerName)\nPrinciple of Least Privilege Applied."
        alert.runModal()
    }

    func setupOverlay() {
        guard let screen = NSScreen.screens.first else { return }
        let barHeight: CGFloat = 33
        let frame = NSRect(x: screen.frame.origin.x - 100, y: screen.frame.maxY - barHeight, width: screen.frame.width + 200, height: barHeight)

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) - 1)
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let view = AuraView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        panel.contentView = view
        self.auraView = view
        self.window = panel
        panel.orderFrontRegardless()
    }

    func updateAura(for app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier?.lowercased() ?? ""
        if bundleID.contains("finder") { self.auraView?.auraColor = .clear; return }

        let mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
        if let rgba = mappings[bundleID] {
            self.auraView?.auraColor = NSColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
        } else {
            self.auraView?.auraColor = NSColor(white: 0.05, alpha: 0.8)
        }
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil { settingsWindow = SettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Settings Window with Individual Removal
class SettingsWindow: NSWindow {
    let mainStack = NSStackView()
    let listStack = NSStackView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 450),
                   styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        self.title = "AuraBar Settings"
        self.isReleasedWhenClosed = false
        
        let content = NSView()
        self.contentView = content
        
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 15
        mainStack.edgeInsets = NSEdgeInsets(top: 25, left: 20, bottom: 25, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        content.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        
        let header = NSTextField(labelWithString: "App Color Mappings")
        header.font = NSFont.boldSystemFont(ofSize: 13)
        mainStack.addArrangedSubview(header)

        let addButton = NSButton(title: "＋ Add Application", target: self, action: #selector(addApp))
        addButton.bezelStyle = .rounded
        mainStack.addArrangedSubview(addButton)
        
        listStack.orientation = .vertical
        listStack.spacing = 12
        listStack.alignment = .leading
        mainStack.addArrangedSubview(listStack)
        
        loadExisting()
    }

    @objc func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            let bundleID = Bundle(url: url)?.bundleIdentifier?.lowercased() ?? "unknown"
            createRow(bundleID: bundleID, color: .gray)
            saveColor(bundleID: bundleID, color: .gray)
        }
    }

    func createRow(bundleID: String, color: NSColor) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        
        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        well.color = color
        well.identifier = NSUserInterfaceItemIdentifier(bundleID)
        well.target = self
        well.action = #selector(colorChanged(_:))

        let name = bundleID.replacingOccurrences(of: "com.", with: "").capitalized
        let label = NSTextField(labelWithString: name)
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let removeBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")!, target: self, action: #selector(removeApp(_:)))
        removeBtn.identifier = NSUserInterfaceItemIdentifier(bundleID)
        removeBtn.isBordered = false

        row.addArrangedSubview(well)
        row.addArrangedSubview(label)
        row.addArrangedSubview(removeBtn)
        listStack.addArrangedSubview(row)
    }

    @objc func colorChanged(_ sender: NSColorWell) {
        guard let bundleID = sender.identifier?.rawValue else { return }
        saveColor(bundleID: bundleID, color: sender.color)
        updateAuraBar()
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
        }
        updateAuraBar()
    }

    func saveColor(bundleID: String, color: NSColor) {
        if let sRGB = color.usingColorSpace(.sRGB) {
            var mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
            mappings[bundleID] = [sRGB.redComponent, sRGB.greenComponent, sRGB.blueComponent, sRGB.alphaComponent]
            UserDefaults.standard.set(mappings, forKey: "AuraMappings")
        }
    }

    func updateAuraBar() {
        if let app = NSWorkspace.shared.frontmostApplication {
            (NSApplication.shared.delegate as? AppDelegate)?.updateAura(for: app)
        }
    }

    func loadExisting() {
        let mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
        for (id, rgba) in mappings {
            createRow(bundleID: id, color: NSColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3]))
        }
    }
}
