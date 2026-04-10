import Foundation

struct TranslationUseCase {
    let translatorProvider: TranslatorProvider
    let tokenizeAndAnnotateUseCase: TokenizeAndAnnotateUseCase
    let translationCacheStore: TranslationCacheStore

    func execute(request: TranslationRequest) async throws -> TranslationResult {
        if let cached = await translationCacheStore.load(for: request) {
            AppEventLogger.log(
                "CACHE_HIT \(request.sourceLang)->\(request.targetLang) \(request.normalizedSourceText)"
            )
            return cached
        }

        AppEventLogger.log(
            "CACHE_MISS \(request.sourceLang)->\(request.targetLang) \(request.normalizedSourceText)"
        )

        let payload = try await translatorProvider.translate(request)
        let result = tokenizeAndAnnotateUseCase.execute(payload: payload, targetLang: request.targetLang)
        await translationCacheStore.save(result, for: request)
        return result
    }
}
