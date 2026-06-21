import Foundation

struct TranslationUseCase {
    let translatorProvider: TranslatorProvider
    let tokenizeAndAnnotateUseCase: TokenizeAndAnnotateUseCase
    let translationCacheStore: TranslationCacheStore

    func execute(request: TranslationRequest) async throws -> TranslationResult {
        if let cached = await translationCacheStore.load(for: request) {
            AppEventLogger.log(
                "CACHE_HIT \(request.sourceLang)->\(request.targetLang) \(request.normalizedSourceText)",
                category: .cache
            )
            return cached
        }

        AppEventLogger.log(
            "CACHE_MISS \(request.sourceLang)->\(request.targetLang) \(request.normalizedSourceText)",
            category: .cache
        )

        let payload = try await translatorProvider.translate(request)
        let result = tokenizeAndAnnotateUseCase.execute(payload: payload)
        await translationCacheStore.save(result, for: request)
        return result
    }
}
