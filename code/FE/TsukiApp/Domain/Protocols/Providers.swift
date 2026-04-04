import Foundation

protocol TranslatorProvider {
    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload
}

protocol TokenizerProvider {
    func tokenize(sentence: String) -> [WordToken]
}
