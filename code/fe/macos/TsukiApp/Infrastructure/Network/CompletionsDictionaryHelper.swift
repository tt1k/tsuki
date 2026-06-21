import Foundation

struct CompletionsDictionaryHelper: TranslatorProvider {
    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct ResponseFormat: Encodable {
            let type: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let responseFormat: ResponseFormat

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case responseFormat = "response_format"
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private struct WordInfo: Decodable {
        struct Token: Decodable {
            let kanji: String
            let furigana: String
        }

        let kanji: String
        let reading: String
        let meaning: String
        let example: String
        let tokens: [Token]
    }

    enum ProviderError: LocalizedError {
        case missingAPIKey(String)
        case invalidResponse(String)
        case httpError(String, Int, String)

        var errorDescription: String? {
            switch self {
            case let .missingAPIKey(providerName):
                return "Missing \(providerName) API key in Settings"
            case let .invalidResponse(providerName):
                return "Unable to parse \(providerName) response"
            case let .httpError(providerName, code, detail):
                return "\(providerName) API request failed: HTTP \(code) - \(detail)"
            }
        }
    }

    private let providerName: String
    private let apiURL: URL
    private let model: String

    init(providerName: String, apiURL: URL, model: String) {
        self.providerName = providerName
        self.apiURL = apiURL
        self.model = model
    }

    init?(configuration: ProviderConfiguration) {
        guard let apiURL = configuration.apiURL else { return nil }
        self.init(
            providerName: configuration.displayName,
            apiURL: apiURL,
            model: configuration.model
        )
    }

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        let apiKey = request.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey(providerName)
        }

        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: "You are an assistant that outputs strict JSON only."),
                .init(role: "user", content: makePrompt(word: request.sourceText, language: request.sourceLang))
            ],
            temperature: 0.2,
            responseFormat: .init(type: "json_object")
        )

        let requestBody = try JSONEncoder().encode(payload)
        urlRequest.httpBody = requestBody

        AppEventLogger.log(
            "AI_REQ \(compactJSON(["provider": request.provider, "endpoint": "chat.completions", "url": apiURL.absoluteString, "request": jsonString(from: requestBody)]))",
            category: .network
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppEventLogger.log(
            "AI_RES \(compactJSON(["provider": request.provider, "endpoint": "chat.completions", "status": statusCode, "response": utf8String(from: data)]))",
            category: .network
        )

        if !(200 ... 299).contains(statusCode) {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.httpError(providerName, statusCode, detail)
        }

        let content = try extractContent(from: data)
        let parsed = try decodeWordInfo(from: content)

        guard !parsed.tokens.isEmpty else {
            throw ProviderError.invalidResponse(providerName)
        }

        let rawTokens = parsed.tokens.map { token in
            RawWordToken(kanji: token.kanji, furigana: token.furigana)
        }

        return ProviderTranslationPayload(
            kanji: parsed.kanji,
            kana: parsed.reading,
            meaning: parsed.meaning,
            sentence: parsed.example,
            tokens: supplementMissingTokens(in: parsed.example, tokens: rawTokens)
        )
    }

    private func supplementMissingTokens(in sentence: String, tokens: [RawWordToken]) -> [RawWordToken] {
        guard !sentence.isEmpty, !tokens.isEmpty else { return tokens }

        var supplemented: [RawWordToken] = []
        var cursor = sentence.startIndex

        for token in tokens {
            guard !token.kanji.isEmpty else { continue }

            if let range = sentence.range(of: token.kanji, range: cursor ..< sentence.endIndex) {
                let gap = String(sentence[cursor ..< range.lowerBound])
                supplemented.append(contentsOf: splitSegments(from: gap))
                supplemented.append(token)
                cursor = range.upperBound
            } else {
                supplemented.append(token)
            }
        }

        let tail = String(sentence[cursor ..< sentence.endIndex])
        supplemented.append(contentsOf: splitSegments(from: tail))

        let filtered = supplemented.filter { !isPunctuationOnly($0.kanji) }
        return filtered.isEmpty ? tokens : filtered
    }

    private func splitSegments(from text: String) -> [RawWordToken] {
        var segments: [RawWordToken] = []
        var current = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || isPunctuationScalar(scalar) {
                if !current.isEmpty {
                    segments.append(RawWordToken(kanji: current, furigana: ""))
                    current = ""
                }
                continue
            }
            current.unicodeScalars.append(scalar)
        }

        if !current.isEmpty {
            segments.append(RawWordToken(kanji: current, furigana: ""))
        }

        return segments
    }

    private func isPunctuationOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return trimmed.unicodeScalars.allSatisfy { isPunctuationScalar($0) }
    }

    private func isPunctuationScalar(_ scalar: UnicodeScalar) -> Bool {
        if CharacterSet.punctuationCharacters.contains(scalar) {
            return true
        }

        let japanesePunctuation = CharacterSet(charactersIn: "、。！？「」『』（）［］【】〈〉《》・…〜～")
        return japanesePunctuation.contains(scalar)
    }

    private func extractContent(from data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse(providerName)
        }
        return content
    }

    private func decodeWordInfo(from rawContent: String) throws -> WordInfo {
        let jsonText = stripCodeFence(rawContent)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ProviderError.invalidResponse(providerName)
        }

        do {
            return try JSONDecoder().decode(WordInfo.self, from: jsonData)
        } catch {
            let object = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
            let normalized = normalize(object: object)
            let normalizedData = try JSONSerialization.data(withJSONObject: normalized)
            return try JSONDecoder().decode(WordInfo.self, from: normalizedData)
        }
    }

    private func stripCodeFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        let parts = trimmed.components(separatedBy: "```")
        guard parts.count >= 3 else { return trimmed }

        var body = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if body.lowercased().hasPrefix("json") {
            body = body.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body
    }

    private func normalize(object: [String: Any]) -> [String: Any] {
        let keyMap: [String: String] = [
            "kanji": "kanji",
            "standard form": "kanji",
            "standard_form": "kanji",
            "reading": "reading",
            "meaning": "meaning",
            "meanings": "meaning",
            "common chinese meanings": "meaning",
            "common_chinese_meanings": "meaning",
            "example": "example",
            "example sentence": "example",
            "example_sentence": "example",
            "tokens": "tokens",
            "example tokens": "tokens",
            "example_tokens": "tokens"
        ]

        var normalized: [String: Any] = [:]
        for (rawKey, value) in object {
            let lowerKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let mapped = keyMap[lowerKey], normalized[mapped] == nil else { continue }
            normalized[mapped] = value
        }

        if let rawTokens = normalized["tokens"] as? [Any] {
            normalized["tokens"] = normalizeTokens(rawTokens)
        } else if let rawTokens = object["tokens"] as? [Any] {
            normalized["tokens"] = normalizeTokens(rawTokens)
        }

        return normalized
    }

    private func normalizeTokens(_ rawTokens: [Any]) -> [[String: String]] {
        rawTokens.compactMap { item in
            guard let dict = item as? [String: Any] else { return nil }

            let kanji = firstString(in: dict, keys: ["kanji", "k", "surface", "text"])
            guard !kanji.isEmpty else { return nil }

            let furigana = firstString(in: dict, keys: ["furigana", "f", "reading", "ruby"])

            return [
                "kanji": kanji,
                "furigana": furigana
            ]
        }
    }

    private func firstString(in dict: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return ""
    }

    private func makePrompt(word: String, language: String) -> String {
        let label = meaningLanguageLabel(from: language)
        let sourceLanguage = meaningLanguageLabel(from: language)
        return """
        You are a Japanese dictionary assistant.

        Task:
        Given an input word or phrase in \(sourceLanguage), return the corresponding natural Japanese dictionary entry as a JSON object with exactly these keys:
        - kanji
        - reading
        - meaning (2-4 common meanings, separated by ;, must be written in \(label))
        - example (one natural Japanese sentence that contains the word)
        - tokens (tokenized words of the example sentence)

        Japanese entry requirements:
        - kanji must be the natural Japanese headword, not a copy of a non-Japanese input
        - if the input is Chinese, translate its meaning into common Japanese first
        - example must be a natural Japanese sentence and must contain the Japanese headword
        - do not use Chinese-only words or Simplified Chinese characters in kanji, example, or tokens unless they are also valid natural Japanese usage

        Token requirements:
        - tokens is an array of objects
        - each token object has exactly: kanji, furigana
        - furigana must be hiragana (empty string allowed when token has no kanji)
        - keep token order consistent with the example sentence
        - do not include punctuation tokens

        Requirements:
        - output JSON only
        - no explanations
        - no extra fields
        - reading must be in hiragana
        - tokens must not be empty

        Word: \(word)
        """
    }

    private func meaningLanguageLabel(from code: String) -> String {
        switch code {
        case "cn": return "Simplified Chinese"
        case "tw": return "Traditional Chinese"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "ru": return "Russian"
        default: return "English"
        }
    }

    private func compactJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object) else { return "{}" }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func jsonString(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let normalized = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else {
            return String(decoding: data, as: UTF8.self)
        }

        return String(decoding: normalized, as: UTF8.self)
    }

    private func utf8String(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
