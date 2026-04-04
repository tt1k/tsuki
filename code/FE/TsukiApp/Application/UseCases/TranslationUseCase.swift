import Foundation

struct TranslationUseCase {
    let translatorProvider: TranslatorProvider
    let tokenizeAndAnnotateUseCase: TokenizeAndAnnotateUseCase

    func execute(request: TranslationRequest) async throws -> TranslationResult {
        let payload = try await translatorProvider.translate(request)
        return tokenizeAndAnnotateUseCase.execute(payload: payload)
    }
}
