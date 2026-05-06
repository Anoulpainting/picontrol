import SwiftUI

@main
struct PiControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Label("PiControl", systemImage: "cpu.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var onboardingWindow:  NSWindow?
    private var onboardingDelegate: OnboardingWindowDelegate?
    private var settingsWindow:    NSWindow?
    private var settingsDelegate:  SettingsWindowDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: "hideOnboardingOnStartup") {
            showOnboarding()
        }
    }

    // MARK: - Onboarding

    func showOnboarding() {
        NSApp.setActivationPolicy(.regular)

        let controller = NSHostingController(rootView: OnboardingView())

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.contentViewController = controller
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.backgroundColor = NSColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 1)
        w.appearance = NSAppearance(named: .darkAqua)
        w.isReleasedWhenClosed = false
        w.level = .floating

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.origin.x + (sf.width  - 560) / 2
            let y = sf.origin.y + (sf.height - 420) / 2
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let onbDelegate = OnboardingWindowDelegate()
        w.delegate = onbDelegate
        onboardingDelegate = onbDelegate

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = w
    }

    // MARK: - Settings

    func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            existing.center()
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "SSH Settings"
        w.isReleasedWhenClosed = false
        w.appearance = NSAppearance(named: .darkAqua)
        w.backgroundColor = NSColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 1)
        w.level = .floating
        w.isReleasedWhenClosed = false

        let delegate = SettingsWindowDelegate()
        w.delegate = delegate
        settingsDelegate = delegate

        let controller = NSHostingController(rootView: SettingsView(onClose: { [weak w] in
            w?.close()
        }))
        w.contentViewController = controller

        // Positionner à gauche du panel MenuBarExtra
        if let panel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible }),
           let screen = panel.screen ?? NSScreen.main {
            let x = max(screen.visibleFrame.minX, panel.frame.minX - 400 - 8)
            w.setFrameTopLeftPoint(NSPoint(x: x, y: panel.frame.maxY))
        } else {
            w.center()
        }
        w.makeKeyAndOrderFront(nil)
        settingsWindow = w
    }
}

// MARK: - Onboarding Window Delegate

class OnboardingWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Settings Window Delegate

class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {}
}
