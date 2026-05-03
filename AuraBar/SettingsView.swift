import SwiftUI
import ServiceManagement
import Combine

// MARK: - Update checker
// Checks automatically on every app launch and every 24 hours.
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var latestChangelog: String?
    @Published var isChecking = false
    @Published var lastChecked: Date? {
        didSet { UserDefaults.standard.set(lastChecked, forKey: "lastUpdateCheck") }
    }

    private let manifestURL = URL(string: "https://raw.githubusercontent.com/adityaonx/AuraBar/main/version.json")!
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
    private let checkInterval: TimeInterval = 86_400   // 24 hours

    init() {
        lastChecked = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date
    }

    var isUpdateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return latest.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    /// notify: true  → popup if update found (auto/background checks)
    /// notify: false → only update published state (manual "Check Now" shows result inline)
    func checkNow(notify: Bool = false) {
        DispatchQueue.main.async { self.isChecking = true }
        URLSession.shared.dataTask(with: manifestURL) { [weak self] data, _, _ in
            guard let self else { return }
            var foundVersion: String?
            var foundChangelog: String?
            if let data,
               let json = try? JSONDecoder().decode([String: String].self, from: data) {
                foundVersion  = json["version"]
                foundChangelog = json["changelog"]
            }
            DispatchQueue.main.async {
                if let v = foundVersion  { self.latestVersion   = v }
                if let c = foundChangelog { self.latestChangelog = c }
                self.lastChecked = Date()
                self.isChecking  = false
                if notify, let latest = foundVersion,
                   latest.compare(self.currentVersion, options: .numeric) == .orderedDescending {
                    self.showUpdatePopup(latestVersion: latest, changelog: foundChangelog)
                }
            }
        }.resume()
    }

    /// Always checks on launch — notifies user if update found.
    /// The 24h throttle only applies to silent background timer checks (if added later).
    func checkOnLaunch() {
        checkNow(notify: true)
    }

    // MARK: Native update alert with changelog
    private func showUpdatePopup(latestVersion: String, changelog: String?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "AuraBar \(latestVersion) is Available"

        var info = "You're on v\(currentVersion). A new version is ready on GitHub."
        if let log = changelog, !log.isEmpty {
            info += "\n\nWhat's new:\n\(log)"
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "https://github.com/adityaonx/AuraBar/releases/latest")!
            )
        }
    }
}

// MARK: - Settings window helper (opened as standalone NSWindow so clicking outside still dismisses the tray popover)
extension Notification.Name {
    static let openSettingsWindow = Notification.Name("AuraBar.openSettingsWindow")
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @StateObject private var updater = UpdateChecker.shared

    var body: some View {
        TabView {
            // ── General ───────────────────────────────────────────────────
            Form {
                Section("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register()   }
                                else       { try SMAppService.mainApp.unregister() }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 180)
            .tabItem { Label("General", systemImage: "gearshape") }

            // ── Updates ───────────────────────────────────────────────────
            UpdatesTabView(updater: updater)
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }

            // ── About ─────────────────────────────────────────────────────
            AboutTabView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Updates Tab
struct UpdatesTabView: View {
    @ObservedObject var updater: UpdateChecker

    var body: some View {
        Form {
            Section("Automatic Updates") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current version: \(updater.currentVersion)")
                            .font(.system(size: 12))
                        Text("Checks automatically on launch and every 24 hours")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if let last = updater.lastChecked {
                            Text("Last checked: \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never checked")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        if updater.isUpdateAvailable, let latest = updater.latestVersion {
                            Label("v\(latest) available", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                                .padding(.top, 2)
                        } else if updater.latestVersion != nil && !updater.isUpdateAvailable {
                            Label("You're up to date", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    Button(updater.isChecking ? "Checking…" : "Check Now") {
                        updater.checkNow(notify: true)
                    }
                    .disabled(updater.isChecking)
                    .buttonStyle(.bordered)
                }
            }

            if updater.isUpdateAvailable {
                Section {
                    if let log = updater.latestChangelog, !log.isEmpty {
                        Text(log)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Download Latest Release") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/adityaonx/AuraBar/releases/latest")!
                        )
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("What's New in \(updater.latestVersion ?? "")")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}

// MARK: - About Tab
struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                Text("AuraBar")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Adaptive tint for maximized windows on macOS")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider().padding(.horizontal, 30)

            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aditya Sahu")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Data Engineer · macOS Tinkerer")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 30)

            HStack(spacing: 8) {
                AboutLinkButton(icon: "chevron.left.forwardslash.chevron.right",
                                label: "Source Code", color: .primary,
                                url: "https://github.com/adityaonx/AuraBar")
                AboutLinkButton(icon: "star.fill",
                                label: "Star", color: .yellow,
                                url: "https://github.com/adityaonx/AuraBar")
                AboutLinkButton(icon: "ant.fill",
                                label: "Report Bug", color: .red,
                                url: "https://github.com/adityaonx/AuraBar/issues/new")
                AboutLinkButton(icon: "arrow.down.circle.fill",
                                label: "Releases", color: .blue,
                                url: "https://github.com/adityaonx/AuraBar/releases")
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Open source · MIT License · © 2025 Aditya Sahu")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 420, height: 340)
        .padding(.top, 20)
    }
}

// MARK: - Reusable link button
struct AboutLinkButton: View {
    let icon: String
    let label: String
    let color: Color
    let url: String

    var body: some View {
        Button(action: { NSWorkspace.shared.open(URL(string: url)!) }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color == .primary ? Color.primary : color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
