import Foundation

struct QwenDictionaryProvider: TranslatorProvider {
    private let provider = CompletionsDictionaryHelper(
        providerName: "Qwen",
        apiURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!,
        model: "qwen-plus"
    )

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await provider.translate(request)
    }
}
