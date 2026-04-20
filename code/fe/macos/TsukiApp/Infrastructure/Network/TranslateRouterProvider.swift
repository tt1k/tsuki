import Foundation

struct TranslateRouterProvider: TranslatorProvider {
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
    private let openAIProvider: TranslatorProvider
    private let geminiProvider: TranslatorProvider
    private let qwenProvider: TranslatorProvider
    private let kimiProvider: TranslatorProvider

    init(
        deepSeekProvider: TranslatorProvider = DeepSeekDictionaryProvider(),
        openAIProvider: TranslatorProvider = OpenAIDictionaryProvider(),
        geminiProvider: TranslatorProvider = GeminiDictionaryProvider(),
        qwenProvider: TranslatorProvider = QwenDictionaryProvider(),
        kimiProvider: TranslatorProvider = KimiDictionaryProvider()
    ) {
        self.deepSeekProvider = deepSeekProvider
        self.openAIProvider = openAIProvider
        self.geminiProvider = geminiProvider
        self.qwenProvider = qwenProvider
        self.kimiProvider = kimiProvider
    }

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        switch request.provider {
        case "deepseek":
            return try await deepSeekProvider.translate(request)
        case "openai":
            return try await openAIProvider.translate(request)
        case "gemini":
            return try await geminiProvider.translate(request)
        case "qwen":
            return try await qwenProvider.translate(request)
        case "kimi":
            return try await kimiProvider.translate(request)
        default:
            throw ProviderError.unsupportedProvider(request.provider)
        }
    }
}
