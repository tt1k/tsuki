import Foundation

struct TranslationRequest {
    let sourceText: String
    let provider: String
    let apiKey: String
    let providerConfiguration: ProviderConfiguration?
    let sourceLang: String
    let targetLang: String
    let useLocalBackend: Bool
    let useLocalDictionaryData: Bool

    init(
        sourceText: String,
        provider: String,
        apiKey: String,
        providerConfiguration: ProviderConfiguration? = nil,
        sourceLang: String,
        targetLang: String,
        useLocalBackend: Bool = true,
        useLocalDictionaryData: Bool = false
    ) {
        self.sourceText = sourceText
        self.provider = provider
        self.apiKey = apiKey
        self.providerConfiguration = providerConfiguration
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.useLocalBackend = useLocalBackend
        self.useLocalDictionaryData = useLocalDictionaryData
    }

    var normalizedSourceText: String {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }
}

struct TranslationResult: Codable {
    let kanji: String
    let kana: String
    let meaning: String
    let sentence: String
    let tokens: [WordToken]

    init(
        kanji: String,
        kana: String,
        meaning: String,
        sentence: String,
        tokens: [WordToken]
    ) {
        self.kanji = kanji
        self.kana = kana
        self.meaning = meaning
        self.sentence = sentence
        self.tokens = tokens
    }
}

struct WordToken: Hashable, Codable {
    let kanji: String
    let furigana: String
    let annotation: String?

    init(kanji: String, furigana: String, annotation: String? = nil) {
        self.kanji = kanji
        self.furigana = furigana
        self.annotation = annotation
    }
}

struct ProviderTranslationPayload {
    let kanji: String
    let kana: String
    let meaning: String
    let sentence: String
    let tokens: [RawWordToken]
}

struct RawWordToken {
    let kanji: String
    let furigana: String
}
