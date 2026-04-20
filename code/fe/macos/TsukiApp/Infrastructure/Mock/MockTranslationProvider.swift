import Foundation

struct MockTranslationProvider: TranslatorProvider {
    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        try await Task.sleep(for: .milliseconds(120))
        return MockSeedData.payload
    }
}
