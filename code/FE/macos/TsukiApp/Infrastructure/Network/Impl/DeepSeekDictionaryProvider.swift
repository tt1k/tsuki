import Foundation

struct DeepSeekDictionaryProvider: TranslatorProvider {
    private let provider = CompletionsDictionaryHelper(
        providerName: "DeepSeek",
        apiURL: URL(string: "https://api.deepseek.com/chat/completions")!,
        model: "deepseek-chat"
    )

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await provider.translate(request)
    }
}
