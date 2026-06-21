import Foundation

struct TranslateRouterProvider: TranslatorProvider {
    enum ProviderError: LocalizedError {
        case unsupportedProvider(String)
        case invalidProviderConfiguration(String, String)

        var errorDescription: String? {
            switch self {
            case let .unsupportedProvider(provider):
                return "Provider '\(provider)' is not supported yet"
            case let .invalidProviderConfiguration(provider, reason):
                return "Provider '\(provider)' has invalid configuration: \(reason)"
            }
        }
    }

    private let localProvider: TranslatorProvider
    private let localSQLiteProvider: TranslatorProvider

    init(
        localProvider: TranslatorProvider = LocalDictionaryProvider(),
        localSQLiteProvider: TranslatorProvider = LocalSQLiteDictionaryProvider()
    ) {
        self.localProvider = localProvider
        self.localSQLiteProvider = localSQLiteProvider
    }

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        if request.useLocalDictionaryData {
            AppEventLogger.log("TRANSLATION_ROUTE provider=\(request.provider) route=local_sqlite_dictionary", category: .database)
            return try await localSQLiteProvider.translate(request)
        }

        if request.useLocalBackend {
            do {
                AppEventLogger.log("TRANSLATION_ROUTE provider=\(request.provider) route=local_query_ds", category: .localBackend)
                return try await localProvider.translate(request)
            } catch {
                AppEventLogger.log("LOCAL_DICT_FAIL provider=\(request.provider) reason=\(error.localizedDescription); fallback=\(request.provider)", category: .localBackend)
            }
        }

        guard let configuration = request.providerConfiguration
            ?? ProviderCatalog.defaultConfiguration(for: request.provider)
        else {
            throw ProviderError.unsupportedProvider(request.provider)
        }

        guard configuration.kind == .openAICompatible else {
            throw ProviderError.unsupportedProvider(request.provider)
        }

        guard let provider = CompletionsDictionaryHelper(configuration: configuration) else {
            throw ProviderError.invalidProviderConfiguration(request.provider, "url must be a valid URL")
        }

        return try await provider.translate(request)
    }
}
