import SwiftUI
import AppKit
import ScreenCaptureKit

// MARK: - Global Permissions
class PermissionManager {
    static let shared = PermissionManager()

    /// CGPreflightScreenCaptureAccess() is cached per-process and won't update
    /// after the user toggles the switch in System Settings without restarting.
    /// We use a live SCShareableContent check instead to get the real state.
    var isScreenCaptureGranted: Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        var granted = false
        let sem = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            do {
                _ = try await SCShareableContent.current
                granted = true
            } catch { }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 1.0)
        return granted
    }

    func requestScreenCapture() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }
    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// MARK: - Visual Effect Background
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Shared Components
struct ModernSliderControl: View {
    @Binding var value: Double
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1)).frame(height: 10)
                Capsule()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * CGFloat(value), height: 10)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .frame(width: 22, height: 22)
                    .offset(x: (geometry.size.width - 22) * CGFloat(value))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        self.value = min(max(0, Double(v.location.x / geometry.size.width)), 1)
                    })
            }
        }.frame(height: 22)
    }
}

// MARK: - View Modifiers
extension View {
    func liquidGlassStyle() -> some View {
        self
            .background(
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
    }
}

struct TahoeRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let sub = subtitle {
                    Text(sub).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.primary.opacity(0.2))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
