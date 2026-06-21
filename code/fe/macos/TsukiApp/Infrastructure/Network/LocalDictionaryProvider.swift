import Foundation

struct LocalDictionaryResponse: Decodable {
    struct Payload: Decodable {
        struct Sentence: Decodable {
            let text: String
            let mean: String?
        }

        struct Kanji: Decodable {
            let text: String
            let mean: String?
            let hiragana: String?
        }

        struct Token: Decodable {
            let k: String
            let f: String?
        }

        let sentence: Sentence
        let kanji: Kanji
        let tokens: [Token]
    }

    let code: Int
    let message: String
    let data: Payload?
}

struct LocalDictionaryProvider: TranslatorProvider {
    enum ProviderError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Local dictionary service is unavailable"
            }
        }
    }

    private let localBaseURL = URL(string: "http://127.0.0.1:5188")!

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        guard await isLocalServiceAvailable() else {
            throw ProviderError.unavailable
        }

        return try await translateByLocalService(request)
    }

    private func isLocalServiceAvailable() async -> Bool {
        var request = URLRequest(url: localBaseURL.appendingPathComponent("query/v"))
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5

        AppEventLogger.log(
            "LOCAL_DICT_HEALTH_REQ \(compactJSON(["url": request.url?.absoluteString ?? "", "method": request.httpMethod ?? "GET"]))",
            category: .localBackend
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppEventLogger.log(
                "LOCAL_DICT_HEALTH_RES \(compactJSON(["status": statusCode, "body": String(decoding: data, as: UTF8.self)]))",
                category: .localBackend
            )
            return (200 ... 299).contains(statusCode)
        } catch {
            AppEventLogger.log("LOCAL_DICT_HEALTH_FAIL \(error.localizedDescription)", category: .localBackend)
            return false
        }
    }

    private func translateByLocalService(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        guard var components = URLComponents(url: localBaseURL.appendingPathComponent("query/ds"), resolvingAgainstBaseURL: false) else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local Dictionary")
        }

        components.queryItems = [
            URLQueryItem(name: "word", value: request.sourceText),
            URLQueryItem(name: "lang", value: request.sourceLang)
        ]

        guard let url = components.url else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local Dictionary")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 8

        AppEventLogger.log(
            "LOCAL_DICT_REQ \(compactJSON(["url": url.absoluteString, "method": urlRequest.httpMethod ?? "GET", "lang": request.sourceLang, "word": request.sourceText]))",
            category: .localBackend
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppEventLogger.log(
            "LOCAL_DICT_RES \(compactJSON(["status": statusCode, "response": String(decoding: data, as: UTF8.self)]))",
            category: .localBackend
        )
        guard (200 ... 299).contains(statusCode) else {
            throw CompletionsDictionaryHelper.ProviderError.httpError("Local Dictionary", statusCode, String(decoding: data, as: UTF8.self))
        }

        let decoded = try JSONDecoder().decode(LocalDictionaryResponse.self, from: data)
        guard decoded.code == 0, let payload = decoded.data else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local Dictionary")
        }

        let rawTokens = payload.tokens
            .filter { !$0.k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RawWordToken(kanji: $0.k, furigana: $0.f ?? "") }

        guard !rawTokens.isEmpty else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local Dictionary")
        }

        return ProviderTranslationPayload(
            kanji: payload.kanji.text,
            kana: payload.kanji.hiragana ?? "",
            meaning: payload.kanji.mean ?? payload.sentence.mean ?? "",
            sentence: payload.sentence.text,
            tokens: rawTokens
        )
    }

    private func compactJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object) else { return "{}" }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }
}
