import Foundation
import SQLite3

final class JMdictKatakanaAnnotationProvider: WordAnnotationProvider {
    private let databaseURL: URL
    private var database: OpaquePointer?

    init?(databaseURL: URL? = JMdictKatakanaAnnotationProvider.defaultDatabaseURL()) {
        guard let databaseURL else {
            return nil
        }

        self.databaseURL = databaseURL
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func annotate(result: TranslationResult) -> TranslationResult {
        let katakanaWords = Set(result.tokens.compactMap { token -> String? in
            let surface = normalizedLookupText(token.kanji)
            return Self.isKatakanaWord(surface) ? surface : nil
        })

        guard !katakanaWords.isEmpty else {
            return result
        }

        let annotations = englishAnnotations(for: katakanaWords)
        guard !annotations.isEmpty else {
            return result
        }

        let annotatedTokens = result.tokens.map { token in
            let lookupText = normalizedLookupText(token.kanji)
            let annotation = Self.isKatakanaWord(lookupText) ? annotations[lookupText] : nil
            return WordToken(
                kanji: token.kanji,
                furigana: token.furigana,
                annotation: annotation ?? token.annotation
            )
        }

        return TranslationResult(
            kanji: result.kanji,
            kana: result.kana,
            meaning: result.meaning,
            sentence: result.sentence,
            tokens: annotatedTokens
        )
    }

    static func defaultDatabaseURL() -> URL? {
        if let bundledURL = Bundle.main.url(forResource: "jmdict", withExtension: "sqlite3") {
            return bundledURL
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("code/fe/db/data/jmdict.sqlite3", isDirectory: false)
        if FileManager.default.fileExists(atPath: developmentURL.path) {
            return developmentURL
        }

        return nil
    }

    private func englishAnnotations(for words: Set<String>) -> [String: String] {
        guard openDatabaseIfNeeded() else {
            return [:]
        }

        var annotations: [String: String] = [:]
        for word in words {
            if let english = englishAnnotation(for: word) {
                annotations[word] = english
            }
        }

        logLookupSummary(words: words, annotations: annotations)
        return annotations
    }

    private func englishAnnotation(for word: String) -> String? {
        guard let database else {
            return nil
        }

        let sql = """
        SELECT english
        FROM entries
        WHERE japanese = ?
        ORDER BY length(english), id
        LIMIT 1
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "JMDICT_PREPARE_LOOKUP_FAIL")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, word, -1, Self.sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let englishRaw = sqlite3_column_text(statement, 0)
        else {
            return nil
        }

        let english = String(cString: englishRaw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return english.isEmpty ? nil : english
    }

    private func openDatabaseIfNeeded() -> Bool {
        if database != nil {
            return true
        }

        var openedDatabase: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &openedDatabase, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let openedDatabase
        else {
            if let openedDatabase {
                sqlite3_close(openedDatabase)
            }
            AppEventLogger.log("JMDICT_OPEN_FAIL path=\(databaseURL.path)", category: .database)
            return false
        }

        database = openedDatabase
        return true
    }

    private func logSQLiteError(prefix: String) {
        guard let database else {
            AppEventLogger.log("\(prefix) path=\(databaseURL.path)", category: .database)
            return
        }

        let message = sqlite3_errmsg(database).map { String(cString: $0) } ?? "unknown"
        AppEventLogger.log("\(prefix) message=\(message)", category: .database)
    }

    private func logLookupSummary(words: Set<String>, annotations: [String: String]) {
        for word in words.sorted() {
            AppEventLogger.log(
                "JMDict words=\(word) hits=\(annotations[word] ?? "miss")",
                category: .database
            )
        }
    }

    private func normalizedLookupText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
    }

    private static func isKatakanaWord(_ text: String) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        return text.unicodeScalars.contains { isKatakanaScalar($0) }
            && text.unicodeScalars.allSatisfy { scalar in
                isKatakanaScalar(scalar) || scalar.value == 0x30FC || scalar.value == 0x30FB
            }
    }

    private static func isKatakanaScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x30A0 ... 0x30FF).contains(scalar.value)
            || (0x31F0 ... 0x31FF).contains(scalar.value)
            || (0xFF66 ... 0xFF9D).contains(scalar.value)
    }

    private static var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
