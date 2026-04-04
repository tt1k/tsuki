import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                NSApp.hide(nil)
                return nil
            }

            if event.modifierFlags.contains(.command), event.keyCode == 36 {
                NotificationCenter.default.post(name: .triggerTranslate, object: nil)
                return nil
            }

            return event
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
        sender.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .focusInput, object: nil)
        return true
    }

    func configureWindowIfNeeded() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.minSize = NSSize(width: DesignTokens.Size.windowWidth, height: 220)
            window.maxSize = NSSize(width: DesignTokens.Size.windowWidth, height: 1200)
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .focusInput, object: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }
}

extension Notification.Name {
    static let triggerTranslate = Notification.Name("TsukiTriggerTranslate")
    static let focusInput = Notification.Name("TsukiFocusInput")
}
