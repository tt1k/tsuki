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
    let headwordKanji: String
    let headwordKana: String
    let meaning: String
    let sentence: String
    let tokens: [WordToken]
    let targetLang: String

    init(
        headwordKanji: String,
        headwordKana: String,
        meaning: String,
        sentence: String,
        tokens: [WordToken],
        targetLang: String = "ja"
    ) {
        self.headwordKanji = headwordKanji
        self.headwordKana = headwordKana
        self.meaning = meaning
        self.sentence = sentence
        self.tokens = tokens
        self.targetLang = targetLang
    }

    enum CodingKeys: String, CodingKey {
        case headwordKanji
        case headwordKana
        case meaning
        case sentence
        case tokens
        case targetLang
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headwordKanji = try container.decode(String.self, forKey: .headwordKanji)
        headwordKana = try container.decode(String.self, forKey: .headwordKana)
        meaning = try container.decode(String.self, forKey: .meaning)
        sentence = try container.decode(String.self, forKey: .sentence)
        tokens = try container.decode([WordToken].self, forKey: .tokens)
        targetLang = try container.decodeIfPresent(String.self, forKey: .targetLang) ?? "ja"
    }
}

struct WordToken: Identifiable, Hashable, Codable {
    let id: UUID
    let kanji: String
    let furigana: String
    let partOfSpeech: String?
    let highlight: HighlightColor
}

enum HighlightColor: String, CaseIterable, Codable {
    case yellow
    case purple
    case green
    case blue
    case gray
}

struct ProviderTranslationPayload {
    let headwordKanji: String
    let headwordKana: String
    let meaning: String
    let sentence: String
    let tokens: [RawWordToken]
}

struct RawWordToken {
    let kanji: String
    let furigana: String
}
