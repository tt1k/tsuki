import Foundation

struct TokenizeAndAnnotateUseCase {
    func execute(payload: ProviderTranslationPayload) -> TranslationResult {
        let tokens = payload.tokens.map { token in
            WordToken(
                kanji: token.kanji,
                furigana: token.furigana
            )
        }

        return TranslationResult(
            kanji: payload.kanji,
            kana: payload.kana,
            meaning: payload.meaning,
            sentence: payload.sentence,
            tokens: tokens
        )
    }
}
