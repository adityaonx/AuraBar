import SwiftUI
import Combine

/// Shown as a standalone floating NSWindow (via MenuBarController.showPermissionWindow)
/// so it sits above the tray popover and System Settings.
struct ScreenCapturePermissionSheet: View {
    var onDismiss: () -> Void

    @State private var granted        = false
    @State private var didOpen        = false
    @State private var pulseAnimation = false

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {

            // ── Icon ────────────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(
                        granted
                        ? LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                               value: pulseAnimation)

                Image(systemName: granted ? "checkmark.shield.fill" : "camera.metering.spot")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        granted
                        ? LinearGradient(colors: [.green, .mint],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.purple, .blue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            // ── Copy ────────────────────────────────────────────────────────
            VStack(spacing: 10) {
                Text(granted ? "Permission Granted!" : "Enable Screen Recording")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(granted
                     ? "AuraBar will now sample your window's top-edge colour and blend the menu bar seamlessly."
                     : didOpen
                       ? "Toggle AuraBar on in Screen Recording, then switch back — it'll detect automatically."
                       : "Dynamic mode reads a thin strip from the top of your focused window to match the menu bar gradient. Your screen is never stored or transmitted.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // ── Action ──────────────────────────────────────────────────────
            if granted {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.8), .blue.opacity(0.4), .clear],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 80, height: 10)
                        Text("Menu bar gradient active")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 14)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())

                    Button(action: onDismiss) {
                        Label("Open AuraBar", systemImage: "paintpalette.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: openSystemSettings) {
                        Label(didOpen ? "Open System Settings again" : "Open Screen Recording Settings",
                              systemImage: "gear")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)

                    if didOpen {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Toggle AuraBar on in Screen Recording…")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Skip — use default colour") {
                        UserDefaults.standard.set(false, forKey: "isDynamicMode")
                        AuraEngine.shared.forceUpdate()
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(36)
        .frame(width: 420)
        .liquidGlassStyle()
        .onAppear {
            pulseAnimation = true
            // Initial live check on appear (in case already granted)
            checkPermission()
        }
        .onReceive(timer) { _ in checkPermission() }
        // Re-check the instant user comes back from System Settings
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if didOpen { checkPermission() }
        }
    }

    // MARK: - Helpers

    private func openSystemSettings() {
        didOpen = true
        PermissionManager.shared.requestScreenCapture()
    }

    private func checkPermission() {
        guard !granted else { return }
        if PermissionManager.shared.isScreenCaptureGranted {
            granted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onDismiss() }
        }
    }
}
