import Foundation

enum MockSeedData {
    static let requestText = "結構"

    static let payload = ProviderTranslationPayload(
        kanji: "結構",
        kana: "けっこう",
        meaning: "还不错; 相当; 足够",
        sentence: "はい そう で 最近 私 も ね その 一人 の 时间 を 楽しむ ために 結構",
        tokens: [
            RawWordToken(kanji: "はい", furigana: ""),
            RawWordToken(kanji: "そう", furigana: ""),
            RawWordToken(kanji: "で", furigana: ""),
            RawWordToken(kanji: "最近", furigana: "さいきん"),
            RawWordToken(kanji: "私", furigana: "わたし"),
            RawWordToken(kanji: "も", furigana: ""),
            RawWordToken(kanji: "ね", furigana: ""),
            RawWordToken(kanji: "その", furigana: ""),
            RawWordToken(kanji: "一人", furigana: "ひとり"),
            RawWordToken(kanji: "の", furigana: ""),
            RawWordToken(kanji: "时间", furigana: "じかん"),
            RawWordToken(kanji: "を", furigana: ""),
            RawWordToken(kanji: "楽しむ", furigana: "たのしむ"),
            RawWordToken(kanji: "ために", furigana: ""),
            RawWordToken(kanji: "結構", furigana: "けっこう")
        ]
    )
}
