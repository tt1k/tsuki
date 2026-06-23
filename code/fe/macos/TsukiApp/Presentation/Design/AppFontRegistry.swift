import CoreText
import Foundation

enum AppFontRegistry {
    static func registerBundledFonts() {
        fontURLs().forEach(registerFont)
    }

    private static func fontURLs() -> [URL] {
        if let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts"),
           !bundledURLs.isEmpty
        {
            return bundledURLs
        }

        let developmentFontsDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("code/fe/macos/TsukiApp/Resources/Fonts", isDirectory: true)
        guard let developmentURLs = try? FileManager.default.contentsOfDirectory(
            at: developmentFontsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return developmentURLs.filter { $0.pathExtension.lowercased() == "ttf" }
    }

    private static func registerFont(_ url: URL) {
        var error: Unmanaged<CFError>?
        guard !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            AppEventLogger.log("Registered font path=\(url.path)", category: .app)
            return
        }

        let description = error?.takeRetainedValue().localizedDescription ?? "unknown"
        AppEventLogger.log("Font registration skipped path=\(url.path) reason=\(description)", category: .app)
    }
}
