import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?

    private var keyMonitor: Any?
    private var statusItem: NSStatusItem?
    private weak var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var pendingURLText: String?
    private let settingsWindowSize = NSSize(width: 700, height: 500)

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        configureStatusItem()
        registerURLEventHandler()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let noModifiers = flags.isEmpty
            let commandOnly = flags == .command

            if event.keyCode == 36, (noModifiers || commandOnly) {
                if !self.shouldTriggerTranslateShortcut() {
                    return event
                }
                if self.isComposingTextInput() {
                    return event
                }
                AppEventLogger.log(commandOnly ? "Cmd+Enter detected" : "Enter detected")
                NotificationCenter.default.post(name: .triggerTranslate, object: nil)
                return nil
            }

            return event
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handleIncomingURL)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let window = mainWindow ?? sender.windows.first else { return true }
        showWindow(window, reposition: true)
        return true
    }

    func configureWindowIfNeeded(
        forceTopRightOnLaunch: Bool,
        appearanceMode: AppearanceMode,
        windowGlassOpacity: Double,
        retriesLeft: Int = 40
    ) {
        if let window = resolveMainWindow() {
            configureMainWindow(
                window,
                forceTopRightOnLaunch: forceTopRightOnLaunch,
                appearanceMode: appearanceMode,
                windowGlassOpacity: windowGlassOpacity
            )
            return
        }

        guard retriesLeft > 0 else {
            AppEventLogger.log("Main window not found during configureWindowIfNeeded")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.configureWindowIfNeeded(
                forceTopRightOnLaunch: forceTopRightOnLaunch,
                appearanceMode: appearanceMode,
                windowGlassOpacity: windowGlassOpacity,
                retriesLeft: retriesLeft - 1
            )
        }
    }

    func applyAppearanceMode(_ mode: AppearanceMode, windowGlassOpacity: Double = 0.86) {
        if let window = mainWindow ?? NSApp.windows.first {
            applyAppearanceMode(mode, to: window, windowGlassOpacity: windowGlassOpacity)
        }

        if let settingsWindow {
            applyAppearanceMode(mode, to: settingsWindow, windowGlassOpacity: windowGlassOpacity)
        }
    }

    func showSettingsWindow(settingsStore: SettingsStore) {
        DispatchQueue.main.async {
            AppEventLogger.log("Opening settings window")
            if let window = self.settingsWindow {
                self.configureSettingsWindowChrome(window)
                self.applyAppearanceMode(
                    settingsStore.appearanceMode,
                    to: window,
                    windowGlassOpacity: settingsStore.windowGlassOpacity
                )
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                AppEventLogger.log("Settings window reused and centered")
                return
            }

            let settingsView = SettingsSheetView()
                .environmentObject(settingsStore)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)

            self.configureSettingsWindowChrome(window)
            self.applyAppearanceMode(
                settingsStore.appearanceMode,
                to: window,
                windowGlassOpacity: settingsStore.windowGlassOpacity
            )
            window.isReleasedWhenClosed = false
            window.minSize = self.settingsWindowSize
            window.maxSize = self.settingsWindowSize
            window.setContentSize(self.settingsWindowSize)
            window.center()
            window.delegate = self

            self.settingsWindow = window

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            AppEventLogger.log("Settings window created and shown")
        }
    }

    private func configureSettingsWindowChrome(_ window: NSWindow) {
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.titlebarSeparatorStyle = .none
        window.setContentBorderThickness(0, for: .minY)
        window.isOpaque = false
        enforceHiddenWindowButtons(on: window)
    }

    private func applyAppearanceMode(_ mode: AppearanceMode, to window: NSWindow, windowGlassOpacity: Double) {
        window.appearance = mode.windowAppearance
        window.backgroundColor = DesignTokens.ColorToken.windowGlassBGNS(opacity: windowGlassOpacity)
    }

    private func resolveMainWindow() -> NSWindow? {
        if let mainWindow {
            return mainWindow
        }

        if let identifiedMainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
            return identifiedMainWindow
        }

        if let titledMainWindow = NSApp.windows.first(where: { $0.title == "Tsuki" }) {
            return titledMainWindow
        }

        return NSApp.windows.first
    }

    private func configureMainWindow(
        _ window: NSWindow,
        forceTopRightOnLaunch: Bool,
        appearanceMode: AppearanceMode,
        windowGlassOpacity: Double
    ) {
        mainWindow = window
        window.identifier = NSUserInterfaceItemIdentifier("main-window")
        window.delegate = self
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        applyAppearanceMode(appearanceMode, to: window, windowGlassOpacity: windowGlassOpacity)
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        enforceHiddenWindowButtons(on: window)

        let fixedSize = NSSize(width: DesignTokens.Size.windowWidth, height: DesignTokens.Size.windowHeight)
        window.minSize = fixedSize
        window.maxSize = fixedSize
        window.setContentSize(fixedSize)
        deliverPendingURLTextIfNeeded()

        if forceTopRightOnLaunch {
            showWindowAtTopRightWithoutFlash(window)
        } else {
            positionWindowUnderStatusItem(window)
            showWindow(window, reposition: false)
        }
    }

    private func enforceHiddenWindowButtons(on window: NSWindow) {
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.circle", accessibilityDescription: "Tsuki")
            button.image?.isTemplate = true
            button.toolTip = "Tsuki"
            button.target = self
            button.action = #selector(toggleMainWindowFromStatusItem)
        }
        self.statusItem = statusItem
    }

    private func registerURLEventHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc
    private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
            let url = URL(string: urlString)
        else {
            return
        }

        handleIncomingURL(url)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "tsuki" else { return }
        guard url.host?.lowercased() == "translate" else { return }
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let text = components.queryItems?.first(where: { $0.name == "text" })?.value,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        guard let window = mainWindow ?? NSApp.windows.first else {
            pendingURLText = text
            return
        }

        showWindow(window, reposition: false)
        NotificationCenter.default.post(name: .fillInputAndTranslate, object: text)
    }

    private func deliverPendingURLTextIfNeeded() {
        guard let text = pendingURLText else { return }
        pendingURLText = nil
        NotificationCenter.default.post(name: .fillInputAndTranslate, object: text)
    }

    @objc
    private func toggleMainWindowFromStatusItem() {
        guard let window = mainWindow ?? NSApp.windows.first else { return }

        if window.isVisible {
            showWindow(window, reposition: false)
            return
        }

        showWindow(window, reposition: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showWindow(_ window: NSWindow, reposition: Bool) {
        enforceHiddenWindowButtons(on: window)
        if reposition {
            positionWindowUnderStatusItem(window)
        }
        window.makeKeyAndOrderFront(nil)
        if reposition {
            positionWindowUnderStatusItem(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .focusInput, object: nil)
    }

    private func showWindowAtTopRightWithoutFlash(_ window: NSWindow) {
        enforceHiddenWindowButtons(on: window)
        window.alphaValue = 0
        window.orderOut(nil)
        positionWindowUnderStatusItem(window)
        window.makeKeyAndOrderFront(nil)
        positionWindowUnderStatusItem(window)
        window.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .focusInput, object: nil)
    }

    func applyDockIconVisibility(_ isVisible: Bool) {
        let primaryWindow = mainWindow ?? NSApp.windows.first
        let sheetWindow = primaryWindow?.attachedSheet
        let keyWindow = NSApp.keyWindow
        let restoreTarget = keyWindow ?? sheetWindow ?? primaryWindow
        let shouldRestoreWindow = restoreTarget?.isVisible == true

        let policy: NSApplication.ActivationPolicy = isVisible ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        guard shouldRestoreWindow else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            if let window = restoreTarget {
                window.makeKeyAndOrderFront(nil)
            }

            if let sheet = (self.mainWindow ?? NSApp.windows.first)?.attachedSheet {
                sheet.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func positionWindowUnderStatusItem(_ window: NSWindow) {
        let horizontalInset: CGFloat = 8
        let verticalGap: CGFloat = 8

        let targetScreen = statusItem?.button?.window?.screen ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else { return }

        let originX = visibleFrame.maxX - window.frame.width - horizontalInset
        let originY = visibleFrame.maxY - window.frame.height - verticalGap
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func isComposingTextInput() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if let textView = responder as? NSTextView {
            return textView.hasMarkedText()
        }
        return false
    }

    private func shouldTriggerTranslateShortcut() -> Bool {
        guard let keyWindow = NSApp.keyWindow else { return false }
        guard let resolvedMainWindow = mainWindow ?? resolveMainWindow() else { return false }
        return keyWindow == resolvedMainWindow
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow {
            settingsWindow = nil
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window == mainWindow || window == settingsWindow else { return }
        enforceHiddenWindowButtons(on: window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender == mainWindow else { return true }
        sender.orderOut(nil)
        return false
    }
}

extension Notification.Name {
    static let triggerTranslate = Notification.Name("TsukiTriggerTranslate")
    static let focusInput = Notification.Name("TsukiFocusInput")
    static let fillInputAndTranslate = Notification.Name("TsukiFillInputAndTranslate")
}
