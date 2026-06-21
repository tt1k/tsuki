import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?

    private var keyMonitor: Any?
    private var settingsInteractionMonitor: Any?
    private var statusItem: NSStatusItem?
    private lazy var statusMenu: NSMenu = makeStatusMenu()
    private weak var recapMenuItem: NSMenuItem?
    private weak var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var settingsStore: SettingsStore?
    private var pendingURLText: String?
    private var isMainWindowPinned = false
    private let recapCommandPath = "/usr/local/bin/tsuki"
    private let settingsWindowSize = NSSize(width: 700, height: 500)
    private let aboutWindowSize = NSSize(width: 300, height: 300)

    private enum RecapInstallResult {
        case success
        case failure(String)
    }

    private struct RecapTerminalApp {
        let name: String
        let bundleIdentifier: String?
        let appURL: URL?
    }

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
            let shortcutFlags = flags.subtracting([.capsLock, .function, .numericPad])
            let optionCommandOnly = shortcutFlags == [.option, .command]
            let isPreviousHistoryShortcut = event.keyCode == UInt16(kVK_LeftArrow) || event.keyCode == UInt16(kVK_UpArrow)
            let isNextHistoryShortcut = event.keyCode == UInt16(kVK_RightArrow) || event.keyCode == UInt16(kVK_DownArrow)

            if optionCommandOnly && (isPreviousHistoryShortcut || isNextHistoryShortcut) {
                if !self.shouldTriggerTranslateShortcut() {
                    return event
                }

                let notificationName: Notification.Name = isPreviousHistoryShortcut
                    ? .navigateTranslationHistoryPrevious
                    : .navigateTranslationHistoryNext
                AppEventLogger.log(
                    isPreviousHistoryShortcut
                        ? "Option+Cmd+Previous history detected"
                        : "Option+Cmd+Next history detected",
                    category: .keyboard
                )
                NotificationCenter.default.post(name: notificationName, object: nil)
                return nil
            }

            if event.keyCode == 36, (noModifiers || commandOnly) {
                if !self.shouldTriggerTranslateShortcut() {
                    return event
                }
                if self.isComposingTextInput() {
                    return event
                }
                AppEventLogger.log(commandOnly ? "Cmd+Enter detected" : "Enter detected", category: .keyboard)
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
            AppEventLogger.log("Main window not found during configureWindowIfNeeded", category: .window)
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

        if let aboutWindow {
            applyAppearanceMode(mode, to: aboutWindow, windowGlassOpacity: windowGlassOpacity)
        }
    }

    @MainActor
    func setSettingsStore(_ settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        updateRecapMenuItem()
    }

    func showSettingsWindow(settingsStore: SettingsStore) {
        DispatchQueue.main.async {
            AppEventLogger.log("Opening settings window", category: .window)
            self.setMainWindowInteractionEnabled(false)
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
                NotificationCenter.default.post(name: .settingsWindowVisibilityChanged, object: true)
                AppEventLogger.log("Settings window reused and centered", category: .window)
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
            NotificationCenter.default.post(name: .settingsWindowVisibilityChanged, object: true)
            AppEventLogger.log("Settings window created and shown", category: .window)
        }
    }

    private func setMainWindowInteractionEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if let settingsInteractionMonitor {
                NSEvent.removeMonitor(settingsInteractionMonitor)
                self.settingsInteractionMonitor = nil
            }
            return
        }

        guard settingsInteractionMonitor == nil else { return }

        let blockedEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]

        settingsInteractionMonitor = NSEvent.addLocalMonitorForEvents(matching: blockedEvents) { [weak self] event in
            guard let self else { return event }
            guard self.settingsWindow?.isVisible == true else { return event }
            guard let targetWindow = event.window else { return event }
            guard let mainWindow = self.mainWindow ?? self.resolveMainWindow() else { return event }
            guard targetWindow == mainWindow else { return event }

            if event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown {
                NSSound.beep()
            }
            return nil
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
        applyMainWindowPinnedState(to: window)
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

    func setMainWindowPinned(_ isPinned: Bool) {
        isMainWindowPinned = isPinned
        guard let window = mainWindow ?? resolveMainWindow() else { return }
        applyMainWindowPinnedState(to: window)
    }

    private func applyMainWindowPinnedState(to window: NSWindow) {
        window.level = isMainWindowPinned ? .floating : .normal
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.stars.circle", accessibilityDescription: "Tsuki")
            button.image?.isTemplate = true
            button.toolTip = "Tsuki"
            button.target = self
            button.action = #selector(showStatusMenuFromStatusItem)
            button.sendAction(on: [.leftMouseUp])
        }
        self.statusItem = statusItem
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let mainWindowItem = NSMenuItem(
            title: "Main Window",
            action: #selector(toggleMainWindowFromStatusMenu(_:)),
            keyEquivalent: ""
        )
        mainWindowItem.target = self
        mainWindowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Main Window")
        menu.addItem(mainWindowItem)

        let installRecapItem = NSMenuItem(
            title: "Install Recap",
            action: #selector(handleRecapFromStatusMenu),
            keyEquivalent: ""
        )
        installRecapItem.target = self
        installRecapItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Install Recap")
        menu.addItem(installRecapItem)
        recapMenuItem = installRecapItem

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About", action: #selector(showAboutFromStatusMenu), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitFromStatusMenu), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        return menu
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
    @MainActor
    private func showStatusMenuFromStatusItem() {
        showStatusMenu()
    }

    @MainActor
    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        let menu = statusMenu
        updateRecapMenuItem()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc
    private func toggleMainWindowFromStatusMenu(_ sender: NSMenuItem) {
        guard let window = mainWindow ?? resolveMainWindow() else { return }

        if window.isVisible {
            window.orderOut(nil)
            return
        }

        showWindow(window, reposition: true)
    }

    @objc
    @MainActor
    private func handleRecapFromStatusMenu() {
        if isRecapInstalled {
            launchRecapFromStatusMenu()
        } else {
            installRecapFromStatusMenu()
        }
    }

    @MainActor
    private var isRecapInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: recapCommandPath)
            && isRecapVersionCurrent
    }

    @MainActor
    private var isRecapVersionCurrent: Bool {
        guard let installedVersion = settingsStore?.recapVersion ?? Self.recapVersionFromConfigFile(),
              !installedVersion.isEmpty
        else {
            return false
        }

        return Self.compareVersion(installedVersion, currentAppVersion) != .orderedAscending
    }

    private static func recapVersionFromConfigFile() -> String? {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tsuki", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)

        guard let data = try? Data(contentsOf: configURL),
              let rawObject = try? JSONSerialization.jsonObject(with: data),
              let object = rawObject as? [String: Any]
        else {
            return nil
        }

        return object["recap_version"] as? String
    }

    @MainActor
    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    @MainActor
    private func updateRecapMenuItem() {
        guard let recapMenuItem else { return }

        if isRecapInstalled {
            recapMenuItem.title = "Recap"
            recapMenuItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Recap")
        } else {
            recapMenuItem.title = "Install Recap"
            recapMenuItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Install Recap")
        }
    }

    @MainActor
    private func installRecapFromStatusMenu() {
        guard let sourceURL = Bundle.main.url(forResource: "tsuki", withExtension: nil) else {
            AppEventLogger.log("Install Recap failed: bundled CLI resource not found", category: .app)
            showRecapInstallAlert(
                title: "Install Recap Failed",
                message: "Bundled recap command was not found in this app."
            )
            return
        }

        AppEventLogger.log("Install Recap requested source=\(sourceURL.path)", category: .app)
        let result = Self.installRecapCommand(from: sourceURL)

        switch result {
        case .success:
            let installedVersion = currentAppVersion
            settingsStore?.markRecapInstalled(version: installedVersion)
            AppEventLogger.log(
                "Install Recap succeeded target=/usr/local/bin/tsuki version=\(installedVersion)",
                category: .app
            )
            updateRecapMenuItem()
            showRecapInstallAlert(
                title: "Recap Installed",
                message: "You can now run `tsuki --recap` in your terminal."
            )
        case let .failure(message):
            AppEventLogger.log("Install Recap failed: \(message)", category: .app)
            showRecapInstallAlert(
                title: "Install Recap Failed",
                message: message
            )
        }
    }

    @MainActor
    private func launchRecapFromStatusMenu() {
        AppEventLogger.log("Recap requested command=\(recapCommandPath)", category: .app)

        do {
            let commandURL = try makeRecapCommandFile()
            let terminalApp = preferredRecapTerminalApp(for: commandURL)
            try launchRecap(commandURL: commandURL, terminalApp: terminalApp)
            AppEventLogger.log(
                "Recap launched commandFile=\(commandURL.path) terminal=\(terminalApp.name) app=\(terminalApp.appURL?.path ?? "system-default")",
                category: .app
            )
        } catch {
            AppEventLogger.log("Recap failed: \(error.localizedDescription)", category: .app)
            showRecapInstallAlert(
                title: "Recap Failed",
                message: error.localizedDescription
            )
        }
    }

    private func makeRecapCommandFile() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsuki-recap", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let commandURL = directoryURL.appendingPathComponent("tsuki-recap.command", isDirectory: false)
        let script = """
        #!/usr/bin/env bash
        clear
        "\(recapCommandPath)" --recap
        """

        try script.write(to: commandURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: commandURL.path
        )
        return commandURL
    }

    private func preferredRecapTerminalApp(for commandURL: URL) -> RecapTerminalApp {
        let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: commandURL)
        if let defaultAppURL,
           !isAppleTerminal(defaultAppURL) {
            return RecapTerminalApp(
                name: appDisplayName(for: defaultAppURL),
                bundleIdentifier: Bundle(url: defaultAppURL)?.bundleIdentifier,
                appURL: defaultAppURL
            )
        }

        if let ghosttyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
            return RecapTerminalApp(
                name: "Ghostty",
                bundleIdentifier: "com.mitchellh.ghostty",
                appURL: ghosttyURL
            )
        }

        if let iTermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") {
            return RecapTerminalApp(
                name: "iTerm2",
                bundleIdentifier: "com.googlecode.iterm2",
                appURL: iTermURL
            )
        }

        return RecapTerminalApp(
            name: defaultAppURL.map { appDisplayName(for: $0) } ?? "system-default",
            bundleIdentifier: defaultAppURL.flatMap { Bundle(url: $0)?.bundleIdentifier },
            appURL: defaultAppURL
        )
    }

    private func launchRecap(commandURL: URL, terminalApp: RecapTerminalApp) throws {
        if let bundleIdentifier = terminalApp.bundleIdentifier {
            try Self.runProcess(
                executablePath: "/usr/bin/open",
                arguments: ["-b", bundleIdentifier, commandURL.path]
            )
            return
        }

        guard NSWorkspace.shared.open(commandURL) else {
            throw NSError(
                domain: "TsukiRecapLauncher",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open recap command file."]
            )
        }
    }

    private func isAppleTerminal(_ appURL: URL) -> Bool {
        Bundle(url: appURL)?.bundleIdentifier == "com.apple.Terminal"
            || appURL.lastPathComponent == "Terminal.app"
    }

    private func appDisplayName(for appURL: URL) -> String {
        appURL.deletingPathExtension().lastPathComponent
    }

    private static func compareVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = versionParts(lhs)
        let rhsParts = versionParts(rhs)
        let maxCount = max(lhsParts.count, rhsParts.count)

        for index in 0 ..< maxCount {
            let lhsPart = index < lhsParts.count ? lhsParts[index] : 0
            let rhsPart = index < rhsParts.count ? rhsParts[index] : 0

            if lhsPart < rhsPart {
                return .orderedAscending
            }

            if lhsPart > rhsPart {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func versionParts(_ version: String) -> [Int] {
        version
            .split { character in
                character == "." || character == "-"
            }
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    private static func installRecapCommand(from sourceURL: URL) -> RecapInstallResult {
        let targetDirectory = "/usr/local/bin"
        let targetPath = "\(targetDirectory)/tsuki"

        do {
            try runProcess(
                executablePath: "/bin/mkdir",
                arguments: ["-p", targetDirectory]
            )
            try runProcess(
                executablePath: "/usr/bin/install",
                arguments: ["-m", "755", sourceURL.path, targetPath]
            )
            return .success
        } catch {
            return installRecapCommandWithAdministratorPrivileges(from: sourceURL)
        }
    }

    private static func installRecapCommandWithAdministratorPrivileges(from sourceURL: URL) -> RecapInstallResult {
        let script = """
        on run argv
          set sourcePath to item 1 of argv
          do shell script "mkdir -p /usr/local/bin && /usr/bin/install -m 755 " & quoted form of sourcePath & " /usr/local/bin/tsuki" with administrator privileges
        end run
        """

        do {
            try runProcess(
                executablePath: "/usr/bin/osascript",
                arguments: ["-e", script, sourceURL.path]
            )
            return .success
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func runProcess(executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let description: String
            if let errorMessage, !errorMessage.isEmpty {
                description = errorMessage
            } else {
                description = "Installer exited with status \(process.terminationStatus)"
            }
            throw NSError(
                domain: "TsukiRecapInstaller",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: description
                ]
            )
        }
    }

    private func showRecapInstallAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title.contains("Failed") ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    @objc
    private func showAboutFromStatusMenu() {
        guard let settingsStore else {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let window = aboutWindow {
            configureAboutWindowChrome(window)
            applyAppearanceMode(
                settingsStore.appearanceMode,
                to: window,
                windowGlassOpacity: settingsStore.windowGlassOpacity
            )
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = TsukiAboutWindowView(
            settingsStore: settingsStore,
            onOK: { [weak self] in
                self?.closeAboutWindow()
            },
            onCopy: { [weak self] text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self?.closeAboutWindow()
            }
        )
            .padding(20)
            .frame(width: aboutWindowSize.width, height: aboutWindowSize.height, alignment: .topLeading)
            .background {
                Rectangle()
                    .fill(DesignTokens.ColorToken.windowGlassBG(opacity: settingsStore.windowGlassOpacity))
                    .ignoresSafeArea()
            }

        let hostingController = NSHostingController(rootView: aboutView)
        let window = NSWindow(contentViewController: hostingController)
        configureAboutWindowChrome(window)
        applyAppearanceMode(
            settingsStore.appearanceMode,
            to: window,
            windowGlassOpacity: settingsStore.windowGlassOpacity
        )
        window.isReleasedWhenClosed = false
        window.minSize = aboutWindowSize
        window.maxSize = aboutWindowSize
        window.setContentSize(aboutWindowSize)
        window.center()
        window.delegate = self
        aboutWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func quitFromStatusMenu() {
        NSApp.terminate(nil)
    }

    private func configureAboutWindowChrome(_ window: NSWindow) {
        window.title = "About"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.titlebarSeparatorStyle = .none
        window.setContentBorderThickness(0, for: .minY)
        window.isOpaque = false
        enforceHiddenWindowButtons(on: window)
    }

    private func closeAboutWindow() {
        guard let aboutWindow else { return }
        aboutWindow.close()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showWindow(_ window: NSWindow, reposition: Bool) {
        applyMainWindowPinnedState(to: window)
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
        applyMainWindowPinnedState(to: window)
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
        if settingsWindow?.isVisible == true {
            return false
        }
        guard let keyWindow = NSApp.keyWindow else { return false }
        guard let resolvedMainWindow = mainWindow ?? resolveMainWindow() else { return false }
        return keyWindow == resolvedMainWindow
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let settingsInteractionMonitor {
            NSEvent.removeMonitor(settingsInteractionMonitor)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow {
            settingsWindow = nil
            setMainWindowInteractionEnabled(true)
            NotificationCenter.default.post(name: .settingsWindowVisibilityChanged, object: false)
        }
        if window == aboutWindow {
            aboutWindow = nil
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window == mainWindow || window == settingsWindow || window == aboutWindow else { return }
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
    static let settingsWindowVisibilityChanged = Notification.Name("TsukiSettingsWindowVisibilityChanged")
    static let navigateTranslationHistoryPrevious = Notification.Name("TsukiNavigateTranslationHistoryPrevious")
    static let navigateTranslationHistoryNext = Notification.Name("TsukiNavigateTranslationHistoryNext")
}
