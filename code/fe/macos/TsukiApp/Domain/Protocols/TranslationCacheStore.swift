import Foundation

protocol TranslationCacheStore {
    func load(for request: TranslationRequest) async -> TranslationResult?
    func save(_ result: TranslationResult, for request: TranslationRequest) async
}

struct NoOpTranslationCacheStore: TranslationCacheStore {
    func load(for request: TranslationRequest) async -> TranslationResult? {
        nil
    }

    func save(_ result: TranslationResult, for request: TranslationRequest) async {}
}
