import Foundation

protocol TranslatorProvider {
    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload
}
