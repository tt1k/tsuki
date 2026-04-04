import Foundation

struct TranslationRequest {
    let sourceText: String
    let sourceLang: String
    let targetLang: String
}

struct TranslationResult {
    let headwordKanji: String
    let headwordKana: String
    let sentence: String
    let tokens: [WordToken]
}

struct WordToken: Identifiable, Hashable {
    let id: UUID
    let kanji: String
    let furigana: String
    let partOfSpeech: String?
    let highlight: HighlightColor
}

enum HighlightColor: String, CaseIterable {
    case yellow
    case purple
    case green
    case blue
    case gray

    static func fromCSSClass(_ cssClass: String) -> HighlightColor {
        switch cssClass {
        case "c-yellow": return .yellow
        case "c-purple": return .purple
        case "c-green": return .green
        case "c-blue": return .blue
        default: return .gray
        }
    }
}

struct ProviderTranslationPayload {
    let headwordKanji: String
    let headwordKana: String
    let sentence: String
    let tokens: [RawWordToken]
}

struct RawWordToken {
    let kanji: String
    let furigana: String
    let colorClass: String
}
