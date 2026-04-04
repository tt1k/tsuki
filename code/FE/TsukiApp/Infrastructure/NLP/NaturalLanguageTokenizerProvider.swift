import Foundation
import NaturalLanguage

struct NaturalLanguageTokenizerProvider: TokenizerProvider {
    func tokenize(sentence: String) -> [WordToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = sentence

        var index = 0
        var tokens: [WordToken] = []

        tokenizer.enumerateTokens(in: sentence.startIndex..<sentence.endIndex) { range, _ in
            let value = String(sentence[range])
            guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return true
            }

            let colors: [HighlightColor] = [.yellow, .purple, .green, .blue, .gray]
            let color = colors[index % colors.count]
            index += 1

            tokens.append(
                WordToken(
                    id: UUID(),
                    kanji: value,
                    furigana: "",
                    partOfSpeech: nil,
                    highlight: color
                )
            )
            return true
        }

        return tokens
    }
}
