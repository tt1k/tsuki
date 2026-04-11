import Foundation

struct GeminiDictionaryProvider: TranslatorProvider {
    private let provider = CompletionsDictionaryHelper(
        providerName: "Gemini",
        apiURL: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!,
        model: "gemini-2.0-flash"
    )

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await provider.translate(request)
    }
}
