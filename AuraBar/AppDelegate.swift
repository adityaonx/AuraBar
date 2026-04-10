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
    
    // Dynamic version retrieval from your Project's Info.plist
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
            showWelcomeAlert()
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

    // MARK: - Robust Update Logic
        @objc func checkUpdates() {
            // Corrected URL: Verified your username from previous screenshots is 'adityaonx'
            let urlString = "https://raw.githubusercontent.com/adityaonx/AuraBar/main/version.json"
            guard let url = URL(string: urlString) else { return }

            print("Checking for updates at: \(urlString)")

            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                // Handle Network Errors (like Sandbox blocking)
                if let error = error {
                    print("Update Error: \(error.localizedDescription)")
                    self?.showUpdateAlert(title: "Connection Error", message: "Could not reach the update server. Error: \(error.localizedDescription)")
                    return
                }

                guard let data = data else { return }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let remoteVersionRaw = json["version"] as? String {
                        
                        let remoteVersion = remoteVersionRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                        let localVersion = self?.appVersion ?? "1.0.0"
                        
                        print("Remote: \(remoteVersion) | Local: \(localVersion)")

                        DispatchQueue.main.async {
                            if remoteVersion.compare(localVersion, options: .numeric) == .orderedDescending {
                                self?.showNewVersionAvailable(version: remoteVersion)
                            } else {
                                self?.showUpdateAlert(title: "Up to Date", message: "AuraBar v\(localVersion) is currently the newest version.")
                            }
                        }
                    } else {
                        print("JSON Key Mismatch: Ensure GitHub has 'version' key.")
                        self?.showUpdateAlert(title: "Parsing Error", message: "Key 'version' not found in JSON.")
                    }
                } catch {
                    print("JSON Parsing Error: \(error.localizedDescription)")
                    self?.showUpdateAlert(title: "Parsing Error", message: "The update manifest on GitHub is malformed.")
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
        alert.informativeText = "AuraBar v\(version) is now available. Would you like to download it?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/adityaonx/AuraBar/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Features
    @objc func toggleLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            try? (service.status == .enabled ? service.unregister() : service.register())
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AuraBar \(appVersion)"
        alert.informativeText = "Developed by \(developerName)\nDynamic menu bar syncing."
        alert.runModal()
    }

    func showWelcomeAlert() {
        let alert = NSAlert()
        alert.messageText = "Welcome to AuraBar"
        alert.informativeText = "Manage your app colors from the palette icon in your menu bar."
        alert.runModal()
    }

    // MARK: - Core Overlay (33pt)
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

// MARK: - Recursion-Free Settings Window
class SettingsWindow: NSWindow {
    let mainStack = NSStackView()
    let listStack = NSStackView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 450),
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
        
        let header = NSTextField(labelWithString: "Mapping Configuration")
        header.font = NSFont.boldSystemFont(ofSize: 13)
        mainStack.addArrangedSubview(header)

        let addButton = NSButton(title: "＋ Add Application", target: self, action: #selector(addApp))
        addButton.bezelStyle = .rounded
        mainStack.addArrangedSubview(addButton)
        
        listStack.orientation = .vertical
        listStack.spacing = 10
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
        }
    }

    func createRow(bundleID: String, color: NSColor) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        
        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: 44, height: 24))
        well.color = color
        well.identifier = NSUserInterfaceItemIdentifier(bundleID)
        well.target = self
        well.action = #selector(colorChanged(_:))

        let name = bundleID.replacingOccurrences(of: "com.", with: "").capitalized
        let label = NSTextField(labelWithString: name)
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        row.addArrangedSubview(well)
        row.addArrangedSubview(label)
        listStack.addArrangedSubview(row)
    }

    @objc func colorChanged(_ sender: NSColorWell) {
        guard let bundleID = sender.identifier?.rawValue else { return }
        if let sRGB = sender.color.usingColorSpace(.sRGB) {
            var mappings = UserDefaults.standard.dictionary(forKey: "AuraMappings") as? [String: [CGFloat]] ?? [:]
            mappings[bundleID] = [sRGB.redComponent, sRGB.greenComponent, sRGB.blueComponent, sRGB.alphaComponent]
            UserDefaults.standard.set(mappings, forKey: "AuraMappings")
        }
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
