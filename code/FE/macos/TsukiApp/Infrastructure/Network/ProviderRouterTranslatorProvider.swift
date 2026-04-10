import Foundation

struct ProviderRouterTranslatorProvider: TranslatorProvider {
    enum ProviderError: LocalizedError {
        case unsupportedProvider(String)

        var errorDescription: String? {
            switch self {
            case let .unsupportedProvider(provider):
                return "Provider '\(provider)' is not supported yet"
            }
        }
    }

    private let deepSeekProvider: TranslatorProvider

    init(deepSeekProvider: TranslatorProvider = DeepSeekDictionaryProvider()) {
        self.deepSeekProvider = deepSeekProvider
    }

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        switch request.provider {
        case "deepseek":
            return try await deepSeekProvider.translate(request)
        default:
            throw ProviderError.unsupportedProvider(request.provider)
        }
    }
}
