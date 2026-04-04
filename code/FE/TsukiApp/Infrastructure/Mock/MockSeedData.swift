import Foundation

enum MockSeedData {
    static let requestText = "結構"

    static let payload = ProviderTranslationPayload(
        headwordKanji: "結構",
        headwordKana: "けっこう",
        sentence: "はい そう で 最近 私 も ね その 一人 の 时间 を 楽しむ ために 結構",
        tokens: [
            RawWordToken(kanji: "はい", furigana: "", colorClass: "c-gray"),
            RawWordToken(kanji: "そう", furigana: "", colorClass: "c-purple"),
            RawWordToken(kanji: "で", furigana: "", colorClass: "c-gray"),
            RawWordToken(kanji: "最近", furigana: "さいきん", colorClass: "c-yellow"),
            RawWordToken(kanji: "私", furigana: "わたし", colorClass: "c-blue"),
            RawWordToken(kanji: "も", furigana: "", colorClass: "c-green"),
            RawWordToken(kanji: "ね", furigana: "", colorClass: "c-gray"),
            RawWordToken(kanji: "その", furigana: "", colorClass: "c-green"),
            RawWordToken(kanji: "一人", furigana: "ひとり", colorClass: "c-yellow"),
            RawWordToken(kanji: "の", furigana: "", colorClass: "c-blue"),
            RawWordToken(kanji: "时间", furigana: "じかん", colorClass: "c-yellow"),
            RawWordToken(kanji: "を", furigana: "", colorClass: "c-green"),
            RawWordToken(kanji: "楽しむ", furigana: "たのしむ", colorClass: "c-green"),
            RawWordToken(kanji: "ために", furigana: "", colorClass: "c-yellow"),
            RawWordToken(kanji: "結構", furigana: "けっこう", colorClass: "c-purple")
        ]
    )
}
