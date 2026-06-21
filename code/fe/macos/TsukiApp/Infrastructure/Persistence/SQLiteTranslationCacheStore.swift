import Foundation
import SQLite3

actor SQLiteTranslationCacheStore: TranslationCacheStore {
    struct CachedRecord {
        let id: Int64
        let queryText: String
        let sourceLang: String
        let targetLang: String
        let result: TranslationResult
        let updatedAt: Date
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let databaseURL: URL
    private var db: OpaquePointer?

    nonisolated var databasePath: String {
        databaseURL.path
    }

    init(fileManager: FileManager = .default) {
        self.databaseURL = Self.makeDatabaseURL(fileManager: fileManager)
        do {
            try fileManager.createDirectory(
                at: self.databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var handle: OpaquePointer?
            let openResult = sqlite3_open_v2(
                self.databaseURL.path,
                &handle,
                SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
                nil
            )

            guard openResult == SQLITE_OK, let handle else {
                let message = handle.flatMap { sqlite3_errmsg($0) }.flatMap { String(cString: $0) } ?? "unknown"
                if let handle {
                    sqlite3_close(handle)
                }
                AppEventLogger.log("CACHE_DB_OPEN_FAIL \(message)", category: .cache)
                return
            }

            try Self.executeSchemaStatements(db: handle)
            db = handle
            AppEventLogger.log("CACHE_DB_READY \(self.databaseURL.path)", category: .cache)
        } catch {
            AppEventLogger.log("CACHE_DB_INIT_FAIL \(error.localizedDescription)", category: .cache)
            if let db {
                sqlite3_close(db)
            }
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func load(for request: TranslationRequest) async -> TranslationResult? {
        guard let db else { return nil }

        let sql = """
        SELECT kanji, kana, meaning, sentence, tokens
        FROM translation_cache
        WHERE (query_text = ? OR kanji = ?)
            AND source_lang = ?
            AND target_lang = ?
            AND provider = ?
            AND use_local_backend = ?
            AND use_local_dictionary_data = ?
        ORDER BY "update" DESC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_LOAD_FAIL", db: db)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        bindText(request.normalizedSourceText, to: 1, in: statement)
        bindText(request.normalizedSourceText, to: 2, in: statement)
        bindText(request.sourceLang, to: 3, in: statement)
        bindText(request.targetLang, to: 4, in: statement)
        bindText(request.provider, to: 5, in: statement)
        sqlite3_bind_int(statement, 6, request.useLocalBackend ? 1 : 0)
        sqlite3_bind_int(statement, 7, request.useLocalDictionaryData ? 1 : 0)

        let step = sqlite3_step(statement)
        guard step == SQLITE_ROW else {
            if step != SQLITE_DONE {
                logSQLiteError(prefix: "CACHE_DB_STEP_LOAD_FAIL", db: db)
            }
            return nil
        }

        guard
            let kanjiRaw = sqlite3_column_text(statement, 0),
            let kanaRaw = sqlite3_column_text(statement, 1),
            let meaningRaw = sqlite3_column_text(statement, 2),
            let sentenceRaw = sqlite3_column_text(statement, 3),
            let tokensRaw = sqlite3_column_text(statement, 4)
        else {
            return nil
        }

        let tokensText = String(cString: tokensRaw)
        guard let tokensData = tokensText.data(using: .utf8) else {
            return nil
        }

        let tokens: [WordToken]
        do {
            tokens = try decoder.decode([WordToken].self, from: tokensData)
        } catch {
            AppEventLogger.log("CACHE_DB_DECODE_TOKENS_FAIL \(error.localizedDescription)", category: .cache)
            return nil
        }

        return TranslationResult(
            kanji: String(cString: kanjiRaw),
            kana: String(cString: kanaRaw),
            meaning: String(cString: meaningRaw),
            sentence: String(cString: sentenceRaw),
            tokens: tokens
        )
    }

    func save(_ result: TranslationResult, for request: TranslationRequest) async {
        guard let db else { return }

        let sql = """
        INSERT INTO translation_cache (
            query_text,
            source_lang,
            target_lang,
            provider,
            use_local_backend,
            use_local_dictionary_data,
            kanji,
            kana,
            meaning,
            sentence,
            tokens,
            "update"
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(query_text, source_lang, target_lang, provider, use_local_backend, use_local_dictionary_data)
        DO UPDATE SET
            query_text = excluded.query_text,
            provider = excluded.provider,
            use_local_backend = excluded.use_local_backend,
            use_local_dictionary_data = excluded.use_local_dictionary_data,
            kanji = excluded.kanji,
            kana = excluded.kana,
            meaning = excluded.meaning,
            sentence = excluded.sentence,
            tokens = excluded.tokens,
            "update" = excluded."update";
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_SAVE_FAIL", db: db)
            return
        }
        defer { sqlite3_finalize(statement) }

        let tokensData: Data
        do {
            tokensData = try encoder.encode(result.tokens)
        } catch {
            AppEventLogger.log("CACHE_DB_ENCODE_TOKENS_FAIL \(error.localizedDescription)", category: .cache)
            return
        }

        let tokensText = String(decoding: tokensData, as: UTF8.self)
        bindText(request.normalizedSourceText, to: 1, in: statement)
        bindText(request.sourceLang, to: 2, in: statement)
        bindText(request.targetLang, to: 3, in: statement)
        bindText(request.provider, to: 4, in: statement)
        sqlite3_bind_int(statement, 5, request.useLocalBackend ? 1 : 0)
        sqlite3_bind_int(statement, 6, request.useLocalDictionaryData ? 1 : 0)
        bindText(result.kanji, to: 7, in: statement)
        bindText(result.kana, to: 8, in: statement)
        bindText(result.meaning, to: 9, in: statement)
        bindText(result.sentence, to: 10, in: statement)
        bindText(tokensText, to: 11, in: statement)
        sqlite3_bind_double(statement, 12, Date().timeIntervalSince1970)

        let step = sqlite3_step(statement)
        guard step == SQLITE_DONE else {
            logSQLiteError(prefix: "CACHE_DB_SAVE_FAIL", db: db)
            return
        }
    }

    func cachedEntryCount() async -> Int {
        guard let db else { return 0 }
        let sql = "SELECT COUNT(*) FROM translation_cache;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_COUNT_FAIL", db: db)
            return 0
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            logSQLiteError(prefix: "CACHE_DB_STEP_COUNT_FAIL", db: db)
            return 0
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    func loadAllRecords() async -> [CachedRecord] {
        guard let db else { return [] }

        let sql = """
        SELECT id, query_text, source_lang, target_lang, kanji, kana, meaning, sentence, tokens, "update"
        FROM translation_cache
        ORDER BY "update" DESC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_LIST_FAIL", db: db)
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records: [CachedRecord] = []

        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }

            guard step == SQLITE_ROW else {
                logSQLiteError(prefix: "CACHE_DB_STEP_LIST_FAIL", db: db)
                break
            }

            guard
                let queryTextRaw = sqlite3_column_text(statement, 1),
                let sourceLangRaw = sqlite3_column_text(statement, 2),
                let targetLangRaw = sqlite3_column_text(statement, 3),
                let kanjiRaw = sqlite3_column_text(statement, 4),
                let kanaRaw = sqlite3_column_text(statement, 5),
                let meaningRaw = sqlite3_column_text(statement, 6),
                let sentenceRaw = sqlite3_column_text(statement, 7),
                let tokensRaw = sqlite3_column_text(statement, 8)
            else {
                continue
            }

            let id = sqlite3_column_int64(statement, 0)
            let tokensText = String(cString: tokensRaw)
            guard let tokensData = tokensText.data(using: .utf8) else {
                continue
            }

            let tokens: [WordToken]
            do {
                tokens = try decoder.decode([WordToken].self, from: tokensData)
            } catch {
                AppEventLogger.log("CACHE_DB_DECODE_LIST_TOKENS_FAIL \(error.localizedDescription)", category: .cache)
                continue
            }

            records.append(
                CachedRecord(
                    id: id,
                    queryText: String(cString: queryTextRaw),
                    sourceLang: String(cString: sourceLangRaw),
                    targetLang: String(cString: targetLangRaw),
                    result: TranslationResult(
                        kanji: String(cString: kanjiRaw),
                        kana: String(cString: kanaRaw),
                        meaning: String(cString: meaningRaw),
                        sentence: String(cString: sentenceRaw),
                        tokens: tokens
                    ),
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
                )
            )
        }

        return records
    }

    func deleteRecords(ids: [Int64]) async -> Int {
        guard let db, !ids.isEmpty else { return 0 }

        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "DELETE FROM translation_cache WHERE id IN (\(placeholders));"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_DELETE_FAIL", db: db)
            return 0
        }
        defer { sqlite3_finalize(statement) }

        for (index, id) in ids.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), id)
        }

        let step = sqlite3_step(statement)
        guard step == SQLITE_DONE else {
            logSQLiteError(prefix: "CACHE_DB_DELETE_FAIL", db: db)
            return 0
        }

        return Int(sqlite3_changes64(db))
    }

    func clearAllRecords() async -> Int {
        guard let db else { return 0 }

        let sql = "DELETE FROM translation_cache;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            logSQLiteError(prefix: "CACHE_DB_PREPARE_CLEAR_FAIL", db: db)
            return 0
        }
        defer { sqlite3_finalize(statement) }

        let step = sqlite3_step(statement)
        guard step == SQLITE_DONE else {
            logSQLiteError(prefix: "CACHE_DB_CLEAR_FAIL", db: db)
            return 0
        }

        return Int(sqlite3_changes64(db))
    }

    private static func executeSchemaStatements(db: OpaquePointer) throws {
        let createCacheTableSQL = """
        CREATE TABLE IF NOT EXISTS translation_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query_text TEXT NOT NULL,
            source_lang TEXT NOT NULL,
            target_lang TEXT NOT NULL,
            provider TEXT NOT NULL DEFAULT '',
            use_local_backend INTEGER NOT NULL DEFAULT 0,
            use_local_dictionary_data INTEGER NOT NULL DEFAULT 0,
            kanji TEXT NOT NULL,
            kana TEXT NOT NULL,
            meaning TEXT NOT NULL,
            sentence TEXT NOT NULL,
            tokens TEXT NOT NULL,
            "update" REAL NOT NULL
        );
        """

        let dropCacheIndexSQL = """
        DROP INDEX IF EXISTS idx_translation_cache_lookup;
        """

        let createCacheIndexSQL = """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_translation_cache_lookup
        ON translation_cache(query_text, source_lang, target_lang, provider, use_local_backend, use_local_dictionary_data);
        """

        let dropKanjiLookupIndexSQL = """
        DROP INDEX IF EXISTS idx_translation_cache_kanji_lookup;
        """

        let createKanjiLookupIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_translation_cache_kanji_lookup
        ON translation_cache(kanji, source_lang, target_lang, provider, use_local_backend, use_local_dictionary_data);
        """

        try Self.execute(sql: createCacheTableSQL, db: db)
        try Self.addColumnIfMissing(
            tableName: "translation_cache",
            columnName: "provider",
            columnDefinition: "provider TEXT NOT NULL DEFAULT ''",
            db: db
        )
        try Self.addColumnIfMissing(
            tableName: "translation_cache",
            columnName: "use_local_backend",
            columnDefinition: "use_local_backend INTEGER NOT NULL DEFAULT 1",
            db: db
        )
        try Self.addColumnIfMissing(
            tableName: "translation_cache",
            columnName: "use_local_dictionary_data",
            columnDefinition: "use_local_dictionary_data INTEGER NOT NULL DEFAULT 0",
            db: db
        )
        try Self.execute(sql: dropCacheIndexSQL, db: db)
        try Self.execute(sql: createCacheIndexSQL, db: db)
        try Self.execute(sql: dropKanjiLookupIndexSQL, db: db)
        try Self.execute(sql: createKanjiLookupIndexSQL, db: db)
    }

    private static func addColumnIfMissing(
        tableName: String,
        columnName: String,
        columnDefinition: String,
        db: OpaquePointer
    ) throws {
        guard try !Self.columnExists(tableName: tableName, columnName: columnName, db: db) else { return }
        try Self.execute(sql: "ALTER TABLE \(tableName) ADD COLUMN \(columnDefinition);", db: db)
    }

    private static func columnExists(tableName: String, columnName: String, db: OpaquePointer) throws -> Bool {
        let sql = "PRAGMA table_info(\(tableName));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            throw NSError(domain: "SQLiteTranslationCacheStore", code: Int(SQLITE_ERROR), userInfo: [NSLocalizedDescriptionKey: message])
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameRaw = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: nameRaw) == columnName {
                return true
            }
        }

        return false
    }

    private static func execute(sql: String, db: OpaquePointer) throws {
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            throw NSError(domain: "SQLiteTranslationCacheStore", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func bindText(_ value: String, to index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func logSQLiteError(prefix: String, db: OpaquePointer) {
        let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
        AppEventLogger.log("\(prefix) \(message)", category: .cache)
    }

    private static var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private static func makeDatabaseURL(fileManager: FileManager) -> URL {
        if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return applicationSupport
                .appendingPathComponent("tsuki", isDirectory: true)
                .appendingPathComponent("translation-cache.sqlite3", isDirectory: false)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("tsuki", isDirectory: true)
            .appendingPathComponent("translation-cache.sqlite3", isDirectory: false)
    }
}
