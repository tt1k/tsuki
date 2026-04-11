import Foundation

struct KimiDictionaryProvider: TranslatorProvider {
    private let provider = CompletionsDictionaryHelper(
        providerName: "Kimi",
        apiURL: URL(string: "https://api.moonshot.cn/v1/chat/completions")!,
        model: "moonshot-v1-8k"
    )

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await provider.translate(request)
    }
}
