import Foundation

struct OpenAIDictionaryProvider: TranslatorProvider {
    private let provider = CompletionsDictionaryHelper(
        providerName: "OpenAI",
        apiURL: URL(string: "https://api.openai.com/v1/chat/completions")!,
        model: "gpt-4o-mini"
    )

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await provider.translate(request)
    }
}
