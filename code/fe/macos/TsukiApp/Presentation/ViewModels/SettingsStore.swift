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
        var useLocalBackend: Bool
        var useLocalDictionaryData: Bool
        var developerOptionsUnlocked: Bool
        var appearanceMode: String
        var appFont: String
        var windowGlassOpacity: Double
        var dockIconVisible: Bool
        var forceTopRightOnLaunch: Bool
        var recapVersion: String
        var apiKeys: [String: String]
        var providerConfigs: [String: ProviderConfiguration]

        enum CodingKeys: String, CodingKey {
            case provider
            case language
            case useLocalBackend = "use_local_backend"
            case useLocalDictionaryData = "use_local_dictionary_data"
            case developerOptionsUnlocked = "developer_options_unlocked"
            case appearanceMode = "appearance_mode"
            case appFont = "app_font"
            case windowGlassOpacity = "window_glass_opacity"
            case dockIconVisible = "dock_icon_visible"
            case forceTopRightOnLaunch = "force_top_right_on_launch"
            case recapVersion = "recap_version"
            case apiKeys = "api_keys"
            case providerConfigs = "provider_list"
        }

        init(
            provider: String,
            language: String,
            useLocalBackend: Bool,
            useLocalDictionaryData: Bool,
            developerOptionsUnlocked: Bool,
            appearanceMode: String,
            appFont: String,
            windowGlassOpacity: Double,
            dockIconVisible: Bool,
            forceTopRightOnLaunch: Bool,
            recapVersion: String,
            apiKeys: [String: String],
            providerConfigs: [String: ProviderConfiguration]
        ) {
            self.provider = provider
            self.language = language
            self.useLocalBackend = useLocalBackend
            self.useLocalDictionaryData = useLocalDictionaryData
            self.developerOptionsUnlocked = developerOptionsUnlocked
            self.appearanceMode = appearanceMode
            self.appFont = appFont
            self.windowGlassOpacity = windowGlassOpacity
            self.dockIconVisible = dockIconVisible
            self.forceTopRightOnLaunch = forceTopRightOnLaunch
            self.recapVersion = recapVersion
            self.apiKeys = apiKeys
            self.providerConfigs = providerConfigs
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            provider = try container.decode(String.self, forKey: .provider)
            language = try container.decode(String.self, forKey: .language)
            useLocalBackend = try container.decodeIfPresent(Bool.self, forKey: .useLocalBackend)
                ?? Defaults.useLocalBackend
            useLocalDictionaryData = try container.decodeIfPresent(Bool.self, forKey: .useLocalDictionaryData)
                ?? Defaults.useLocalDictionaryData
            developerOptionsUnlocked = try container.decodeIfPresent(Bool.self, forKey: .developerOptionsUnlocked)
                ?? Defaults.developerOptionsUnlocked
            appearanceMode = try container.decodeIfPresent(String.self, forKey: .appearanceMode)
                ?? Defaults.appearanceMode.rawValue
            appFont = try container.decodeIfPresent(String.self, forKey: .appFont)
                ?? Defaults.appFont.rawValue
            windowGlassOpacity = Self.clampWindowGlassOpacity(
                try container.decodeIfPresent(Double.self, forKey: .windowGlassOpacity)
                    ?? Defaults.windowGlassOpacity
            )
            dockIconVisible = try container.decodeIfPresent(Bool.self, forKey: .dockIconVisible)
                ?? Defaults.dockIconVisible
            forceTopRightOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .forceTopRightOnLaunch)
                ?? Defaults.forceTopRightOnLaunch
            recapVersion = try container.decodeIfPresent(String.self, forKey: .recapVersion)
                ?? Defaults.recapVersion
            apiKeys = try container.decodeIfPresent([String: String].self, forKey: .apiKeys)
                ?? [:]
            let decodedProviderConfigs = try container.decodeIfPresent([String: ProviderConfiguration].self, forKey: .providerConfigs)
                ?? [:]
            providerConfigs = ProviderCatalog.normalizedCustomConfigurations(decodedProviderConfigs)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(provider, forKey: .provider)
            try container.encode(language, forKey: .language)
            try container.encode(useLocalBackend, forKey: .useLocalBackend)
            try container.encode(useLocalDictionaryData, forKey: .useLocalDictionaryData)
            try container.encode(developerOptionsUnlocked, forKey: .developerOptionsUnlocked)
            try container.encode(appearanceMode, forKey: .appearanceMode)
            try container.encode(appFont, forKey: .appFont)
            try container.encode(windowGlassOpacity, forKey: .windowGlassOpacity)
            try container.encode(dockIconVisible, forKey: .dockIconVisible)
            try container.encode(forceTopRightOnLaunch, forKey: .forceTopRightOnLaunch)
            try container.encode(recapVersion, forKey: .recapVersion)
            try container.encode(apiKeys, forKey: .apiKeys)
            try container.encode(providerConfigs, forKey: .providerConfigs)
        }

        private static func clampWindowGlassOpacity(_ value: Double) -> Double {
            min(max(value, 0.70), 1.00)
        }
    }

    private enum Defaults {
        static let provider = "deepseek"
        static let language = "en"
        static let useLocalBackend = true
        static let useLocalDictionaryData = false
        static let developerOptionsUnlocked = false
        static let appearanceMode: AppearanceMode = .dark
        static let appFont: AppFontOption = .system
        static let windowGlassOpacity = 0.86
        static let dockIconVisible = true
        static let forceTopRightOnLaunch = true
        static let recapVersion = ""
    }

    private let supportedLanguages: Set<String> = [
        "cn", "tw", "en", "ja", "ko", "es", "fr", "de", "ru"
    ]

    @Published var provider: String {
        didSet { saveIfNeeded() }
    }

    @Published var language: String {
        didSet { saveIfNeeded() }
    }

    @Published var useLocalBackend: Bool {
        didSet { saveIfNeeded() }
    }

    @Published var useLocalDictionaryData: Bool {
        didSet { saveIfNeeded() }
    }

    @Published var developerOptionsUnlocked: Bool {
        didSet { saveIfNeeded() }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet { saveIfNeeded() }
    }

    @Published var appFont: AppFontOption {
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

    @Published private(set) var recapVersion: String {
        didSet { saveIfNeeded() }
    }

    @Published private var apiKeys: [String: String] {
        didSet { saveIfNeeded() }
    }

    @Published private var providerConfigs: [String: ProviderConfiguration] {
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
        self.useLocalBackend = Defaults.useLocalBackend
        self.useLocalDictionaryData = Defaults.useLocalDictionaryData
        self.developerOptionsUnlocked = Defaults.developerOptionsUnlocked
        self.appearanceMode = Defaults.appearanceMode
        self.appFont = Defaults.appFont
        self.windowGlassOpacity = Defaults.windowGlassOpacity
        self.dockIconVisible = Defaults.dockIconVisible
        self.forceTopRightOnLaunch = Defaults.forceTopRightOnLaunch
        self.recapVersion = Defaults.recapVersion
        self.apiKeys = [:]
        self.providerConfigs = [:]
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
        providerConfigs = ProviderCatalog.normalizedCustomConfigurations(snapshot.providerConfigs)
        provider = supportedProviders.contains(snapshot.provider) ? snapshot.provider : Defaults.provider
        let normalizedLanguage = Self.normalizeLanguageCode(snapshot.language)
        language = supportedLanguages.contains(normalizedLanguage) ? normalizedLanguage : Defaults.language
        useLocalBackend = snapshot.useLocalBackend
        useLocalDictionaryData = snapshot.useLocalDictionaryData
        developerOptionsUnlocked = snapshot.developerOptionsUnlocked
        appearanceMode = AppearanceMode(rawValue: snapshot.appearanceMode) ?? Defaults.appearanceMode
        appFont = AppFontOption(rawValue: snapshot.appFont) ?? Defaults.appFont
        windowGlassOpacity = Self.clampWindowGlassOpacity(snapshot.windowGlassOpacity)
        dockIconVisible = snapshot.dockIconVisible
        forceTopRightOnLaunch = snapshot.forceTopRightOnLaunch
        recapVersion = snapshot.recapVersion
        apiKeys = snapshot.apiKeys.filter { supportedProviders.contains($0.key) }
        isApplyingSnapshot = false
    }

    private func saveIfNeeded() {
        guard !isApplyingSnapshot else { return }
        saveToDisk()
    }

    private func saveToDisk() {
        let normalizedLanguage = Self.normalizeLanguageCode(language)
        let normalizedProviderConfigs = ProviderCatalog.normalizedCustomConfigurations(providerConfigs)
        let effectiveProviderConfigs = ProviderCatalog.merged(with: normalizedProviderConfigs)
        let normalizedSupportedProviders = Set(effectiveProviderConfigs.keys)
        let config = ConfigFile(
            provider: normalizedSupportedProviders.contains(provider) ? provider : Defaults.provider,
            language: supportedLanguages.contains(normalizedLanguage) ? normalizedLanguage : Defaults.language,
            useLocalBackend: useLocalBackend,
            useLocalDictionaryData: useLocalDictionaryData,
            developerOptionsUnlocked: developerOptionsUnlocked,
            appearanceMode: appearanceMode.rawValue,
            appFont: appFont.rawValue,
            windowGlassOpacity: Self.clampWindowGlassOpacity(windowGlassOpacity),
            dockIconVisible: dockIconVisible,
            forceTopRightOnLaunch: forceTopRightOnLaunch,
            recapVersion: recapVersion,
            apiKeys: apiKeys.filter { normalizedSupportedProviders.contains($0.key) },
            providerConfigs: effectiveProviderConfigs
        )

        do {
            try fileManager.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try Self.prettyPrintedJSONData(from: encoder.encode(config))
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

    func markRecapInstalled(version: String) {
        guard recapVersion != version else { return }
        recapVersion = version
    }

    var providerOptions: [ProviderOptionDescriptor] {
        let effectiveProviderConfigs = ProviderCatalog.merged(with: providerConfigs)
        return ProviderCatalog.orderedProviderIDs(from: effectiveProviderConfigs).map { providerID in
            ProviderOptionDescriptor(
                id: providerID,
                title: effectiveProviderConfigs[providerID]?.displayName ?? providerID
            )
        }
    }

    func providerConfiguration(for provider: String) -> ProviderConfiguration? {
        ProviderCatalog.merged(with: providerConfigs)[provider]
    }

    private var supportedProviders: Set<String> {
        Set(ProviderCatalog.merged(with: providerConfigs).keys)
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

    private static func prettyPrintedJSONData(from data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try prettyPrintedJSON(object) + "\n"
        return Data(json.utf8)
    }

    private static func prettyPrintedJSON(_ object: Any, indentLevel: Int = 0) throws -> String {
        if let dictionary = object as? [String: Any] {
            return try prettyPrintedDictionary(dictionary, indentLevel: indentLevel)
        }

        if let array = object as? [Any] {
            return try prettyPrintedArray(array, indentLevel: indentLevel)
        }

        if let string = object as? String {
            return try jsonStringLiteral(string)
        }

        if let number = object as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        }

        if object is NSNull {
            return "null"
        }

        throw EncodingError.invalidValue(
            object,
            EncodingError.Context(codingPath: [], debugDescription: "Unsupported JSON value")
        )
    }

    private static func prettyPrintedDictionary(_ dictionary: [String: Any], indentLevel: Int) throws -> String {
        guard !dictionary.isEmpty else { return "{}" }

        let currentIndent = jsonIndent(level: indentLevel)
        let childIndent = jsonIndent(level: indentLevel + 1)
        let lines = try dictionary.keys.sorted().map { key in
            guard let rawValue = dictionary[key] else {
                throw EncodingError.invalidValue(
                    dictionary,
                    EncodingError.Context(codingPath: [], debugDescription: "Missing JSON dictionary value")
                )
            }
            let value = try prettyPrintedJSON(rawValue, indentLevel: indentLevel + 1)
            return "\(childIndent)\(try jsonStringLiteral(key)): \(value)"
        }

        return "{\n\(lines.joined(separator: ",\n"))\n\(currentIndent)}"
    }

    private static func prettyPrintedArray(_ array: [Any], indentLevel: Int) throws -> String {
        guard !array.isEmpty else { return "[]" }

        let currentIndent = jsonIndent(level: indentLevel)
        let childIndent = jsonIndent(level: indentLevel + 1)
        let lines = try array.map { item in
            "\(childIndent)\(try prettyPrintedJSON(item, indentLevel: indentLevel + 1))"
        }

        return "[\n\(lines.joined(separator: ",\n"))\n\(currentIndent)]"
    }

    private static func jsonStringLiteral(_ value: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private static func jsonIndent(level: Int) -> String {
        String(repeating: " ", count: level * 4)
    }
}
