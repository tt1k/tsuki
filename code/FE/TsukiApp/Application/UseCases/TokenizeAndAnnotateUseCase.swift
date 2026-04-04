import Foundation

struct TokenizeAndAnnotateUseCase {
    let tokenizerProvider: TokenizerProvider

    func execute(payload: ProviderTranslationPayload) -> TranslationResult {
        let tokens: [WordToken]
        if payload.tokens.isEmpty {
            tokens = tokenizerProvider.tokenize(sentence: payload.sentence)
        } else {
            tokens = payload.tokens.map {
                WordToken(
                    id: UUID(),
                    kanji: $0.kanji,
                    furigana: $0.furigana,
                    partOfSpeech: nil,
                    highlight: .fromCSSClass($0.colorClass)
                )
            }
        }

        return TranslationResult(
            headwordKanji: payload.headwordKanji,
            headwordKana: payload.headwordKana,
            sentence: payload.sentence,
            tokens: tokens
        )
    }
}
