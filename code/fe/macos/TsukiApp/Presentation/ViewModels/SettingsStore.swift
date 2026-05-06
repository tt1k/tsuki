import AppKit
import Foundation
import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable {
    case dark
    case light
    case auto

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        case .auto:
            return nil
        }
    }

    var windowAppearance: NSAppearance? {
        switch self {
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        case .auto:
            return nil
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private struct ConfigFile: Codable {
        var provider: String
        var language: String
        var useCustomModel: Bool
        var appearanceMode: String
        var windowGlassOpacity: Double
        var dockIconVisible: Bool
        var forceTopRightOnLaunch: Bool
        var apiKeys: [String: String]

        enum CodingKeys: String, CodingKey {
            case provider
            case language
            case useCustomModel
            case appearanceMode
            case windowGlassOpacity
            case dockIconVisible
            case forceTopRightOnLaunch
            case apiKeys
        }

        init(
            provider: String,
            language: String,
            useCustomModel: Bool,
            appearanceMode: String,
            windowGlassOpacity: Double,
            dockIconVisible: Bool,
            forceTopRightOnLaunch: Bool,
            apiKeys: [String: String]
        ) {
            self.provider = provider
            self.language = language
            self.useCustomModel = useCustomModel
            self.appearanceMode = appearanceMode
            self.windowGlassOpacity = windowGlassOpacity
            self.dockIconVisible = dockIconVisible
            self.forceTopRightOnLaunch = forceTopRightOnLaunch
            self.apiKeys = apiKeys
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            provider = try container.decode(String.self, forKey: .provider)
            language = try container.decode(String.self, forKey: .language)
            useCustomModel = try container.decodeIfPresent(Bool.self, forKey: .useCustomModel) ?? Defaults.useCustomModel
            appearanceMode = try container.decodeIfPresent(String.self, forKey: .appearanceMode) ?? Defaults.appearanceMode.rawValue
            windowGlassOpacity = Self.clampWindowGlassOpacity(
                try container.decodeIfPresent(Double.self, forKey: .windowGlassOpacity) ?? Defaults.windowGlassOpacity
            )
            dockIconVisible = try container.decodeIfPresent(Bool.self, forKey: .dockIconVisible) ?? Defaults.dockIconVisible
            forceTopRightOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .forceTopRightOnLaunch) ?? Defaults.forceTopRightOnLaunch
            apiKeys = try container.decodeIfPresent([String: String].self, forKey: .apiKeys) ?? [:]
        }

        private static func clampWindowGlassOpacity(_ value: Double) -> Double {
            min(max(value, 0.70), 1.00)
        }
    }

    private enum Defaults {
        static let provider = "deepseek"
        static let language = "en"
        static let useCustomModel = false
        static let appearanceMode: AppearanceMode = .dark
        static let windowGlassOpacity = 0.86
        static let dockIconVisible = true
        static let forceTopRightOnLaunch = true
    }

    private let supportedProviders: Set<String> = [
        "deepseek", "openai", "gemini", "qwen", "kimi"
    ]
    private let supportedLanguages: Set<String> = [
        "cn", "tw", "en", "ja", "ko", "es", "fr", "de", "ru"
    ]

    @Published var provider: String {
        didSet { saveIfNeeded() }
    }

    @Published var language: String {
        didSet { saveIfNeeded() }
    }

    @Published var useCustomModel: Bool {
        didSet { saveIfNeeded() }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet { saveIfNeeded() }
    }

    @Published var windowGlassOpacity: Double {
        didSet {
            let clamped = Self.clampWindowGlassOpacity(windowGlassOpacity)
            if windowGlassOpacity != clamped {
                windowGlassOpacity = clamped
                return
            }
            saveIfNeeded()
        }
    }

    @Published var dockIconVisible: Bool {
        didSet { saveIfNeeded() }
    }

    @Published var forceTopRightOnLaunch: Bool {
        didSet { saveIfNeeded() }
    }

    @Published private var apiKeys: [String: String] {
        didSet { saveIfNeeded() }
    }

    private let fileManager: FileManager
    private let configURL: URL
    private var isApplyingSnapshot = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.configURL = Self.makeConfigURL(fileManager: fileManager)
        self.provider = Defaults.provider
        self.language = Defaults.language
        self.useCustomModel = Defaults.useCustomModel
        self.appearanceMode = Defaults.appearanceMode
        self.windowGlassOpacity = Defaults.windowGlassOpacity
        self.dockIconVisible = Defaults.dockIconVisible
        self.forceTopRightOnLaunch = Defaults.forceTopRightOnLaunch
        self.apiKeys = [:]
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: configURL.path) else {
            saveToDisk()
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode(ConfigFile.self, from: data)
            apply(snapshot: decoded)
            saveToDisk()
        } catch {
            saveToDisk()
        }
    }

    private func apply(snapshot: ConfigFile) {
        isApplyingSnapshot = true
        provider = supportedProviders.contains(snapshot.provider) ? snapshot.provider : Defaults.provider
        let normalizedLanguage = Self.normalizeLanguageCode(snapshot.language)
        language = supportedLanguages.contains(normalizedLanguage) ? normalizedLanguage : Defaults.language
        useCustomModel = snapshot.useCustomModel
        appearanceMode = AppearanceMode(rawValue: snapshot.appearanceMode) ?? Defaults.appearanceMode
        windowGlassOpacity = Self.clampWindowGlassOpacity(snapshot.windowGlassOpacity)
        dockIconVisible = snapshot.dockIconVisible
        forceTopRightOnLaunch = snapshot.forceTopRightOnLaunch
        apiKeys = snapshot.apiKeys.filter { supportedProviders.contains($0.key) }
        isApplyingSnapshot = false
    }

    private func saveIfNeeded() {
        guard !isApplyingSnapshot else { return }
        saveToDisk()
    }

    private func saveToDisk() {
        let normalizedLanguage = Self.normalizeLanguageCode(language)
        let config = ConfigFile(
            provider: supportedProviders.contains(provider) ? provider : Defaults.provider,
            language: supportedLanguages.contains(normalizedLanguage) ? normalizedLanguage : Defaults.language,
            useCustomModel: useCustomModel,
            appearanceMode: appearanceMode.rawValue,
            windowGlassOpacity: Self.clampWindowGlassOpacity(windowGlassOpacity),
            dockIconVisible: dockIconVisible,
            forceTopRightOnLaunch: forceTopRightOnLaunch,
            apiKeys: apiKeys
        )

        do {
            try fileManager.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            return
        }
    }

    func apiKey(for provider: String) -> String {
        apiKeys[provider] ?? ""
    }

    func setAPIKey(_ key: String, for provider: String) {
        guard supportedProviders.contains(provider) else { return }

        if key.isEmpty {
            _ = apiKeys.removeValue(forKey: provider)
            return
        }

        if apiKeys[provider] != key {
            apiKeys[provider] = key
        }
    }

    private static func makeConfigURL(fileManager: FileManager) -> URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tsuki", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    private static func normalizeLanguageCode(_ language: String) -> String {
        language
    }

    private static func clampWindowGlassOpacity(_ value: Double) -> Double {
        min(max(value, 0.70), 1.00)
    }
}
