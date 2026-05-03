import SwiftUI
import Combine

struct OnboardingView: View {
    @State private var screenGranted = PermissionManager.shared.isScreenCaptureGranted
    @State private var accessibilityGranted = PermissionManager.shared.isAccessibilityGranted
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    VStack(spacing: 8) {
                        Text("Welcome to AuraBar")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("Personalize your menu bar with adaptive tints.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                
                VStack(spacing: 16) {
                    PermissionRow(
                        title: "Accessibility",
                        description: "Required to detect maximized windows.",
                        isOptional: false,
                        isGranted: accessibilityGranted,
                        action: { PermissionManager.shared.requestAccessibilityPrompt() }
                    )
                    
                    PermissionRow(
                        title: "Screen Recording",
                        description: "Optional: Enables Dynamic Color sampling.",
                        isOptional: true,
                        isGranted: screenGranted,
                        action: { PermissionManager.shared.requestScreenCapture() }
                    )
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        AppDelegate.shared?.launchTrayApp()
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!accessibilityGranted)
                    
                    Text(accessibilityGranted ? "Everything is set!" : "Accessibility is required to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            }
            .padding(50)
        }
        .frame(width: 550, height: 620)
        .background(Color.clear)
        .liquidGlassStyle()
        .onReceive(timer) { _ in
            accessibilityGranted = PermissionManager.shared.isAccessibilityGranted
            screenGranted = PermissionManager.shared.isScreenCaptureGranted
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isOptional: Bool
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    if isOptional {
                        Text("OPTIONAL")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .opacity(0.6)
                    }
                }
                Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.title3)
            } else {
                Button("Enable", action: action).buttonStyle(.bordered).controlSize(.regular)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
