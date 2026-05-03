import AppKit
import ScreenCaptureKit
import SwiftUI

enum WindowState { case normal, maximized, fullscreen }

// Posted when dynamic mode is toggled ON but screen capture isn't granted yet
extension Notification.Name {
    static let requestScreenCaptureForDynamic = Notification.Name("AuraBar.requestScreenCaptureForDynamic")
    static let screenCaptureGrantedReturnToTray = Notification.Name("AuraBar.screenCaptureGrantedReturnToTray")
}

@MainActor
class AuraEngine {
    static let shared = AuraEngine()
    
    // Each screen gets its own NSPanel acting as an overlay.
    // We use a gradient-capable NSView inside each panel so we can
    // blend the sampled window-top colour across the bar height.
    private var overlays: [NSScreen: (panel: NSPanel, view: GradientBarView)] = [:]
    private var isRunning = false

    @AppStorage("isDynamicMode")    private var isDynamicMode    = true
    @AppStorage("isEngineActive")   private var isEngineActive   = true
    @AppStorage("globalDefaultHex") private var globalDefaultHex = "#1A1A1A"
    @AppStorage("perAppTints")      private var perAppTintsData: Data = Data()
    @AppStorage("excludedApps")     var excludedAppsData: Data = Data()
    @AppStorage("tintIntensity")    private var tintIntensity    = 0.85
    // Separate opacity for the dark backing layer so the bar background is fully covered
    @AppStorage("darkTintOpacity")  private var darkTintOpacity  = 0.92

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in Task { @MainActor in self.refreshOverlays() } }
        refreshOverlays()
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { await self.handleUpdate() }
        }
    }

    func forceUpdate() { Task { await handleUpdate() } }

    // MARK: - Core update loop

    private func handleUpdate() async {
        guard isRunning, isEngineActive,
              let app = NSWorkspace.shared.frontmostApplication else { hideAll(); return }

        let bundleID = app.bundleIdentifier ?? ""
        let excludedList: [String] = (try? JSONDecoder().decode([String].self, from: excludedAppsData)) ?? []
        if excludedList.contains(bundleID) { hideAll(); return }

        guard getWindowState(for: app) == .maximized else { hideAll(); return }

        let perAppDict: [String: String] = (try? JSONDecoder().decode([String: String].self, from: perAppTintsData)) ?? [:]

        if let customHex = perAppDict[bundleID] {
            applyFlat(NSColor(hex: customHex) ?? .black)
        } else if isDynamicMode {
            if PermissionManager.shared.isScreenCaptureGranted {
                await sampleAndApplyGradient(for: app)
            } else {
                // Permission missing — notify UI to show the permission sheet,
                // fall back to solid default colour in the meantime.
                NotificationCenter.default.post(name: .requestScreenCaptureForDynamic, object: nil)
                applyFlat(NSColor(hex: globalDefaultHex) ?? .black)
            }
        } else {
            applyFlat(NSColor(hex: globalDefaultHex) ?? .black)
        }
    }

    // MARK: - Apply colour / gradient

    /// Solid fill — used for custom per-app tints and the static default.
    /// darkTintOpacity acts as a hard floor so the native menu-bar background
    /// is always fully covered regardless of the tintIntensity slider value.
    private func applyFlat(_ color: NSColor) {
        let alpha    = CGFloat(tintIntensity)
        let minAlpha = CGFloat(darkTintOpacity)          // floor: bar bg must be fully overlapped
        for (_, entry) in overlays {
            entry.view.setGradient(top: color.withAlphaComponent(max(alpha, minAlpha)),
                                   bottom: color.withAlphaComponent(max(alpha * 0.85, minAlpha * 0.88)))
            entry.panel.orderFront(nil)
        }
    }

    /// Gradient fill — top matches the sampled window-edge colour,
    /// bottom fades toward transparent. Both ends scale with tintIntensity
    /// so the slider controls the overall strength of the dynamic tint.
    /// darkTintOpacity ensures the bottom edge never drops low enough
    /// to let the native bar background bleed through.
    private func applyGradient(top: NSColor, bottom: NSColor) {
        let alpha    = CGFloat(tintIntensity)
        let minAlpha = CGFloat(darkTintOpacity)          // floor: bar bg must be fully overlapped
        for (_, entry) in overlays {
            entry.view.setGradient(top: top.withAlphaComponent(max(alpha, minAlpha)),
                                   bottom: bottom.withAlphaComponent(max(alpha * 0.80, minAlpha * 0.85)))
            entry.panel.orderFront(nil)
        }
    }

    func hideAll() {
        overlays.values.forEach { $0.panel.orderOut(nil) }
    }

    // MARK: - Overlay construction

    func refreshOverlays() {
        overlays.values.forEach { $0.panel.close() }
        overlays.removeAll()

        for screen in NSScreen.screens {
            let barHeight  = screen.frame.maxY - screen.visibleFrame.maxY
            let finalHeight = barHeight > 0 ? barHeight : 24
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - finalHeight,
                width: screen.frame.width,
                height: finalHeight
            )

            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.level            = NSWindow.Level(Int(CGWindowLevelForKey(.statusWindow)) - 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]   // NO .fullScreenAuxiliary
            panel.ignoresMouseEvents = true
            panel.backgroundColor  = .clear
            panel.hasShadow        = false
            panel.isOpaque         = false

            let gradView = GradientBarView(frame: NSRect(origin: .zero, size: frame.size))
            panel.contentView = gradView

            overlays[screen] = (panel: panel, view: gradView)
        }
    }

    // MARK: - Window state detection

    func getWindowState(for app: NSRunningApplication) -> WindowState {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard let appRef = focusedApp as! AXUIElement?,
              let screen = NSScreen.main else { return .normal }

        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &window)
        guard let winRef = window as! AXUIElement? else { return .normal }

        // Read frame first (needed for both checks below)
        var frameValue: CFTypeRef?
        AXUIElementCopyAttributeValue(winRef, "AXFrame" as CFString, &frameValue)
        var axFrame = CGRect.zero
        if let fv = frameValue { AXValueGetValue(fv as! AXValue, .cgRect, &axFrame) }

        // 1. Standard macOS fullscreen space — AXFullScreen == true
        var fullscreenValue: CFTypeRef?
        AXUIElementCopyAttributeValue(winRef, "AXFullScreen" as CFString, &fullscreenValue)
        if let fsVal = fullscreenValue as? Bool, fsVal { return .fullscreen }

        // 2. Non-standard fullscreen (VLC-style): borderless window covering entire screen.frame
        //    including the menu-bar area. A maximized window can never reach screen.frame.maxY.
        let windowTop = axFrame.origin.y + axFrame.size.height
        if axFrame.size.width  >= screen.frame.width  - 10,
           axFrame.size.height >= screen.frame.height - 5,
           windowTop           >= screen.frame.maxY   - 5 {
            return .fullscreen
        }

        // 3. Maximized: touches the top of the *visible* frame (just below the menu bar)
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if axFrame.origin.y <= menuBarHeight + 10,
           axFrame.size.width >= screen.visibleFrame.width - 20 {
            return .maximized
        }

        return .normal
    }

    // MARK: - Dynamic colour sampling

    /// Captures a thin horizontal strip from the top of the focused window,
    /// computes the average colour, and applies a gradient overlay.
    private func sampleAndApplyGradient(for app: NSRunningApplication) async {
        do {
            let content = try await SCShareableContent.current
            guard let scWindow = content.windows.first(where: {
                $0.owningApplication?.processID == app.processIdentifier && $0.isOnScreen
            }) else { return }

            // Capture the full window at reduced resolution to keep it cheap
            let cfg = SCStreamConfiguration()
            cfg.width  = 200
            cfg.height = 60

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: scWindow),
                configuration: cfg
            )

            let rep = NSBitmapImageRep(cgImage: image)
            let topColour    = averageColor(rep, inRect: NSRect(x: 0, y: 0, width: rep.pixelsWide, height: min(8, rep.pixelsHigh)))
            let bottomColour = averageColor(rep, inRect: NSRect(x: 0, y: min(8, rep.pixelsHigh - 1),
                                                                width: rep.pixelsWide,
                                                                height: min(20, rep.pixelsHigh - 8)))

            applyGradient(top: topColour ?? NSColor(hex: globalDefaultHex) ?? .black,
                          bottom: bottomColour ?? .clear)
        } catch {
            applyFlat(NSColor(hex: globalDefaultHex) ?? .black)
        }
    }

    /// Returns the perceptual average colour of a rect within a bitmap rep.
    private func averageColor(_ rep: NSBitmapImageRep, inRect rect: NSRect) -> NSColor? {
        guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return nil }
        var r: Double = 0, g: Double = 0, b: Double = 0, count: Double = 0
        let x0 = Int(rect.minX), x1 = min(Int(rect.maxX), rep.pixelsWide)
        let y0 = Int(rect.minY), y1 = min(Int(rect.maxY), rep.pixelsHigh)
        // Sample every other pixel for performance
        var y = y0
        while y < y1 {
            var x = x0
            while x < x1 {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    r += c.redComponent; g += c.greenComponent; b += c.blueComponent; count += 1
                }
                x += 2
            }
            y += 2
        }
        guard count > 0 else { return nil }
        var components: [CGFloat] = [r/count, g/count, b/count, 1.0]
        return NSColor(colorSpace: NSColorSpace.sRGB, components: &components, count: 4)
    }
}

// MARK: - Gradient bar view

/// An NSView that renders a top-to-bottom gradient.
/// Used as the content view of each overlay panel.
final class GradientBarView: NSView {
    private var topColor:    NSColor = .clear
    private var bottomColor: NSColor = .clear

    func setGradient(top: NSColor, bottom: NSColor) {
        topColor = top; bottomColor = bottom
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let colors   = [topColor.cgColor, bottomColor.cgColor] as CFArray
        let space    = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
        // Draw top → bottom
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: bounds.height),
                               end:   CGPoint(x: 0, y: 0),
                               options: [])
    }
}
