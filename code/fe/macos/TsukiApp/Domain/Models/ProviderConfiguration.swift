import Foundation

enum ProviderKind: String, Codable {
    case openAICompatible = "openai_compatible"
}

struct ProviderConfiguration: Codable, Equatable {
    let displayName: String
    let kind: ProviderKind
    let baseURL: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case displayName = "name"
        case kind
        case url
        case model
    }

    init(
        displayName: String,
        kind: ProviderKind = .openAICompatible,
        baseURL: String,
        model: String
    ) {
        self.displayName = displayName
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? ""
        let rawKind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        kind = ProviderKind(rawValue: rawKind) ?? .openAICompatible
        baseURL = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(baseURL, forKey: .url)
        try container.encode(model, forKey: .model)
    }

    var apiURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else { return nil }
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            return nil
        }
        return url
    }

    func normalized(providerID: String, fallback: ProviderConfiguration? = nil) -> ProviderConfiguration {
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        return ProviderConfiguration(
            displayName: normalizedDisplayName.isEmpty ? fallback?.displayName ?? providerID : normalizedDisplayName,
            kind: kind,
            baseURL: normalizedBaseURL.isEmpty ? fallback?.baseURL ?? "" : normalizedBaseURL,
            model: normalizedModel.isEmpty ? fallback?.model ?? "" : normalizedModel
        )
    }

}

struct ProviderOptionDescriptor: Identifiable, Equatable {
    let id: String
    let title: String
}

enum ProviderCatalog {
    static let defaultProviderOrder = ["deepseek"]

    static let defaultConfigurations: [String: ProviderConfiguration] = [
        "deepseek": ProviderConfiguration(
            displayName: "DeepSeek",
            baseURL: "https://api.deepseek.com/chat/completions",
            model: "deepseek-v4-flash"
        )
    ]

    static func defaultConfiguration(for providerID: String) -> ProviderConfiguration? {
        defaultConfigurations[providerID]
    }

    static func normalizedCustomConfigurations(_ customConfigurations: [String: ProviderConfiguration]) -> [String: ProviderConfiguration] {
        var normalizedConfigurations: [String: ProviderConfiguration] = [:]

        for (rawProviderID, configuration) in customConfigurations {
            let providerID = rawProviderID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !providerID.isEmpty else { continue }

            let normalized = configuration.normalized(
                providerID: providerID,
                fallback: defaultConfigurations[providerID]
            )
            guard !normalized.baseURL.isEmpty, !normalized.model.isEmpty else { continue }
            normalizedConfigurations[providerID] = normalized
        }

        return normalizedConfigurations
    }

    static func merged(with customConfigurations: [String: ProviderConfiguration]) -> [String: ProviderConfiguration] {
        var merged = defaultConfigurations

        for (providerID, configuration) in normalizedCustomConfigurations(customConfigurations) {
            merged[providerID] = configuration
        }

        return merged
    }

    static func orderedProviderIDs(from configurations: [String: ProviderConfiguration]) -> [String] {
        let builtIns = defaultProviderOrder.filter { configurations[$0] != nil }
        let custom = configurations.keys
            .filter { !defaultProviderOrder.contains($0) }
            .sorted()
        return builtIns + custom
    }

}
