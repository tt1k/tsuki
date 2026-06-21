import Foundation
import SQLite3

final class LocalSQLiteDictionaryProvider: TranslatorProvider {
    enum ProviderError: LocalizedError {
        case unavailable
        case notFound(String)
        case invalidTokens(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Local dictionary data is unavailable"
            case let .notFound(word):
                return "Local dictionary data has no entry for '\(word)'"
            case let .invalidTokens(word):
                return "Local dictionary data has invalid tokens for '\(word)'"
            }
        }
    }

    private struct MainInfo {
        let id: Int64
        let kanji: String
        let hiragana: String
        let sentence: String
        let tokens: String
    }

    private struct MeanInfo {
        let lang: String
        let meanW: String
        let meanS: String
    }

    private struct TokenItem: Decodable {
        let k: String
        let f: String?
    }

    private let databaseURL: URL?

    init(databaseURL: URL? = LocalSQLiteDictionaryProvider.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        guard let databaseURL else {
            AppEventLogger.log("LOCAL_SQLITE_DICT_UNAVAILABLE", category: .database)
            throw ProviderError.unavailable
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db
        else {
            if let db {
                sqlite3_close(db)
            }
            AppEventLogger.log("LOCAL_SQLITE_DICT_OPEN_FAIL path=\(databaseURL.path)", category: .database)
            throw ProviderError.unavailable
        }
        defer { sqlite3_close(db) }

        let word = request.normalizedSourceText
        let lang = request.sourceLang
        let mainInfo: MainInfo?

        if Self.isJapaneseWord(word) {
            AppEventLogger.log("LOCAL_SQLITE_DICT_REQ route=kanji word=\(word) lang=\(lang)", category: .database)
            mainInfo = findLatestMainByKanji(word, db: db)
        } else {
            AppEventLogger.log("LOCAL_SQLITE_DICT_REQ route=seek word=\(word) lang=\(lang)", category: .database)
            mainInfo = findLatestMainBySeekTerm(word, db: db)
        }

        guard let mainInfo,
              let meanInfo = findMean(wordID: mainInfo.id, lang: lang, db: db)
        else {
            AppEventLogger.log("LOCAL_SQLITE_DICT_MISS word=\(word) lang=\(lang)", category: .database)
            throw ProviderError.notFound(word)
        }

        let tokens = try parseTokens(mainInfo.tokens, word: word)
        AppEventLogger.log("LOCAL_SQLITE_DICT_HIT word=\(word) lang=\(meanInfo.lang) kanji=\(mainInfo.kanji)", category: .database)

        return ProviderTranslationPayload(
            kanji: mainInfo.kanji,
            kana: mainInfo.hiragana,
            meaning: meanInfo.meanW,
            sentence: mainInfo.sentence,
            tokens: tokens
        )
    }

    static func defaultDatabaseURL() -> URL? {
        if let bundledURL = Bundle.main.url(forResource: "tsuki", withExtension: "sqlite3") {
            return bundledURL
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("code/db/ipadict/result/tsuki.sqlite3", isDirectory: false)
        if FileManager.default.fileExists(atPath: developmentURL.path) {
            return developmentURL
        }

        return nil
    }

    private func findLatestMainByKanji(_ word: String, db: OpaquePointer) -> MainInfo? {
        let sql = """
        SELECT id, kanji, hiragana, sentence, tokens
        FROM tsuki_main
        WHERE kanji = ?
        ORDER BY updated DESC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "LOCAL_SQLITE_DICT_PREPARE_MAIN_FAIL", db: db)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        bindText(word, to: 1, in: statement)
        return stepMain(statement)
    }

    private func findLatestMainBySeekTerm(_ word: String, db: OpaquePointer) -> MainInfo? {
        let sql = """
        SELECT main.id, main.kanji, main.hiragana, main.sentence, main.tokens
        FROM tsuki_seek seek
        INNER JOIN tsuki_main main ON main.id = seek.word_id
        WHERE seek.term = ?
        ORDER BY seek.updated DESC, seek.id DESC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "LOCAL_SQLITE_DICT_PREPARE_SEEK_FAIL", db: db)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        bindText(word, to: 1, in: statement)
        return stepMain(statement)
    }

    private func findMean(wordID: Int64, lang: String, db: OpaquePointer) -> MeanInfo? {
        let sql = """
        SELECT lang, mean_w, mean_s
        FROM tsuki_mean
        WHERE word_id = ?
          AND lang = ?
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "LOCAL_SQLITE_DICT_PREPARE_MEAN_FAIL", db: db)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, wordID)
        bindText(lang, to: 2, in: statement)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let langRaw = sqlite3_column_text(statement, 0),
              let meanWRaw = sqlite3_column_text(statement, 1),
              let meanSRaw = sqlite3_column_text(statement, 2)
        else {
            return nil
        }

        return MeanInfo(
            lang: String(cString: langRaw),
            meanW: String(cString: meanWRaw),
            meanS: String(cString: meanSRaw)
        )
    }

    private func stepMain(_ statement: OpaquePointer) -> MainInfo? {
        guard sqlite3_step(statement) == SQLITE_ROW,
              let kanjiRaw = sqlite3_column_text(statement, 1),
              let hiraganaRaw = sqlite3_column_text(statement, 2),
              let sentenceRaw = sqlite3_column_text(statement, 3),
              let tokensRaw = sqlite3_column_text(statement, 4)
        else {
            return nil
        }

        return MainInfo(
            id: sqlite3_column_int64(statement, 0),
            kanji: String(cString: kanjiRaw),
            hiragana: String(cString: hiraganaRaw),
            sentence: String(cString: sentenceRaw),
            tokens: String(cString: tokensRaw)
        )
    }

    private func parseTokens(_ tokensJSON: String, word: String) throws -> [RawWordToken] {
        guard let data = tokensJSON.data(using: .utf8) else {
            throw ProviderError.invalidTokens(word)
        }

        do {
            let decoded = try JSONDecoder().decode([TokenItem].self, from: data)
            let tokens = decoded
                .filter { !$0.k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { RawWordToken(kanji: $0.k, furigana: $0.f ?? "") }
            guard !tokens.isEmpty else {
                throw ProviderError.invalidTokens(word)
            }
            return tokens
        } catch let error as ProviderError {
            throw error
        } catch {
            AppEventLogger.log("LOCAL_SQLITE_DICT_TOKEN_PARSE_FAIL word=\(word) reason=\(error.localizedDescription)", category: .database)
            throw ProviderError.invalidTokens(word)
        }
    }

    private static func isJapaneseWord(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return trimmed.unicodeScalars.contains { scalar in
            (0x3040 ... 0x309F).contains(scalar.value)
                || (0x30A0 ... 0x30FF).contains(scalar.value)
                || (0x31F0 ... 0x31FF).contains(scalar.value)
                || (0x3400 ... 0x4DBF).contains(scalar.value)
                || (0x4E00 ... 0x9FFF).contains(scalar.value)
                || (0xF900 ... 0xFAFF).contains(scalar.value)
                || (0x20000 ... 0x2A6DF).contains(scalar.value)
                || (0x2A700 ... 0x2B73F).contains(scalar.value)
                || (0x2B740 ... 0x2B81F).contains(scalar.value)
                || (0x2B820 ... 0x2CEAF).contains(scalar.value)
                || (0x2CEB0 ... 0x2EBEF).contains(scalar.value)
                || (0xFF00 ... 0xFFEF).contains(scalar.value)
        }
    }

    private func bindText(_ value: String, to index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func logSQLiteError(prefix: String, db: OpaquePointer) {
        let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
        AppEventLogger.log("\(prefix) message=\(message)", category: .database)
    }

    private static var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
