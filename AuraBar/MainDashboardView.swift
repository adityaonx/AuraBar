import SwiftUI
import Combine

struct MainDashboardView: View {
    @AppStorage("isDynamicMode")    private var isDynamicMode    = true
    @AppStorage("isEngineActive")   private var isEngineActive   = true
    @AppStorage("globalDefaultHex") private var globalDefaultHex = "#1A1A1A"
    @AppStorage("tintIntensity")    private var tintIntensity    = 0.85
    // Minimum opacity floor that guarantees the native bar bg is fully covered
    @AppStorage("darkTintOpacity")  private var darkTintOpacity  = 0.92

    @State private var showingAppRules      = false
    @State private var screenGranted        = PermissionManager.shared.isScreenCaptureGranted

    // Timer to poll for permission grant while sheet is showing
    private let permissionTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AuraBar Active")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Adaptive tint for maximized windows")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isEngineActive)
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .onChange(of: isEngineActive) { _, _ in AuraEngine.shared.forceUpdate() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── Mode picker ─────────────────────────────────────────────────
            Picker("", selection: $isDynamicMode) {
                Text("Dynamic").tag(true)
                Text("Custom").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .onChange(of: isDynamicMode) { _, newValue in
                if newValue {
                    screenGranted = PermissionManager.shared.isScreenCaptureGranted
                    if !screenGranted {
                        AppDelegate.shared?.menuBarController?.showPermissionWindow()
                    }
                }
                AuraEngine.shared.forceUpdate()
            }

            // ── Settings card ───────────────────────────────────────────────
            VStack(spacing: 0) {

                // Default tint row (only visible in Custom mode)
                if !isDynamicMode {
                    HStack(spacing: 8) {
                        TahoeRow(icon: "paintpalette.fill", iconColor: .orange,
                                 title: "Default Tint", showChevron: false)
                        Spacer()
                        Button(action: {
                            globalDefaultHex = "#1A1A1A"
                            AuraEngine.shared.forceUpdate()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(4)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        ColorPicker("", selection: Binding(
                            get: { Color(hex: globalDefaultHex) ?? .black },
                            set: { globalDefaultHex = $0.toHex() ?? "#1A1A1A"
                                  AuraEngine.shared.forceUpdate() }
                        ))
                        .labelsHidden()
                        .padding(.trailing, 12)
                    }

                    Divider().padding(.horizontal, 12).opacity(0.3)
                }

                // Dynamic mode status row
                if isDynamicMode {
                    HStack(spacing: 12) {
                        Image(systemName: screenGranted ? "wand.and.sparkles" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(screenGranted ? Color.purple : Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Gradient Sampling")
                                .font(.system(size: 13, weight: .medium))
                            Text(screenGranted
                                 ? "Blending menu bar with window top"
                                 : "Screen Recording permission needed")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !screenGranted {
                            Button("Enable") {
                                AppDelegate.shared?.menuBarController?.showPermissionWindow()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.orange)
                            .padding(.trailing, 12)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.trailing, 12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider().padding(.horizontal, 12).opacity(0.3)
                }

                // Intensity slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TahoeRow(icon: "slider.horizontal.3", iconColor: .blue,
                                 title: "Tint Intensity", showChevron: false)
                        Spacer()
                        Text("\(Int(tintIntensity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 12)
                    }
                    ModernSliderControl(value: $tintIntensity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .onChange(of: tintIntensity) { _, _ in AuraEngine.shared.forceUpdate() }
                }

                Divider().padding(.horizontal, 12).opacity(0.3)

                // Dark tint opacity slider — controls how strongly the overlay
                // covers the native menu-bar background
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TahoeRow(icon: "circle.lefthalf.filled", iconColor: .indigo,
                                 title: "Dark Tint Coverage", showChevron: false)
                        Spacer()
                        Text("\(Int(darkTintOpacity * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 12)
                    }
                    ModernSliderControl(value: $darkTintOpacity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .onChange(of: darkTintOpacity) { _, _ in AuraEngine.shared.forceUpdate() }
                }

                Divider().padding(.horizontal, 12).opacity(0.3)

                Button(action: { showingAppRules = true }) {
                    TahoeRow(icon: "checklist", iconColor: .green,
                             title: "Manage Rules & Exclusions")
                }.buttonStyle(.plain)
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 20)

            // ── Footer ──────────────────────────────────────────────────────
            HStack {
                Button(action: { NotificationCenter.default.post(name: .openSettingsWindow, object: nil) }) {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 12) {
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 360)
        .liquidGlassStyle()
        .sheet(isPresented: $showingAppRules) { AppManagementView() }
        .onReceive(permissionTimer) { _ in
            screenGranted = PermissionManager.shared.isScreenCaptureGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestScreenCaptureForDynamic)) { _ in
            screenGranted = PermissionManager.shared.isScreenCaptureGranted
        }
    }
}
