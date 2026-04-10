import Foundation

struct TokenizeAndAnnotateUseCase {
    func execute(payload: ProviderTranslationPayload, targetLang: String) -> TranslationResult {
        let colors = HighlightColor.allCases
        var previousColorIndex: Int?

        let tokens = payload.tokens.enumerated().map { index, token in
            let seedText = payload.sentence + token.kanji + String(index)
            let seed = seedText.unicodeScalars.reduce(UInt64(0)) { partial, scalar in
                (partial &* 31) &+ UInt64(scalar.value)
            }

            var colorIndex = Int(seed % UInt64(colors.count))
            if let previousColorIndex, colorIndex == previousColorIndex {
                let step = Int(seed % UInt64(colors.count - 1)) + 1
                colorIndex = (colorIndex + step) % colors.count
            }
            previousColorIndex = colorIndex

            let highlight = colors[colorIndex]

            return WordToken(
                id: UUID(),
                kanji: token.kanji,
                furigana: token.furigana,
                partOfSpeech: nil,
                highlight: highlight
            )
        }

        return TranslationResult(
            headwordKanji: payload.headwordKanji,
            headwordKana: payload.headwordKana,
            meaning: payload.meaning,
            sentence: payload.sentence,
            tokens: tokens,
            targetLang: targetLang
        )
    }
}
