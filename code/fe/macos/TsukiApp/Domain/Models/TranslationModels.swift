import Foundation

struct TranslationRequest {
    let sourceText: String
    let provider: String
    let apiKey: String
    let sourceLang: String
    let targetLang: String

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
