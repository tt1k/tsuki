import Foundation

struct DeepSeekDictionaryProvider: TranslatorProvider {
    private struct LocalResponse: Decodable {
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

    private let remoteProvider = CompletionsDictionaryHelper(
        providerName: "DeepSeek",
        apiURL: URL(string: "https://api.deepseek.com/chat/completions")!,
        model: "deepseek-chat"
    )

    private let localBaseURL = URL(string: "http://127.0.0.1:5188")!

    func translate(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        if !request.useCustomModel {
            if await isLocalServiceAvailable() {
                do {
                    AppEventLogger.log("TRANSLATION_ROUTE provider=deepseek route=local_query_ds")
                    return try await translateByLocalService(request)
                } catch {
                    AppEventLogger.log("LOCAL_DS_FAIL \(error.localizedDescription); fallback=deepseek")
                }
            } else {
                AppEventLogger.log("LOCAL_DS_UNAVAILABLE fallback=deepseek")
            }
        }

        return try await remoteProvider.translate(request)
    }

    private func isLocalServiceAvailable() async -> Bool {
        var request = URLRequest(url: localBaseURL.appendingPathComponent("query/v"))
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5

        AppEventLogger.log(
            "LOCAL_DS_HEALTH_REQ \(compactJSON(["url": request.url?.absoluteString ?? "", "method": request.httpMethod ?? "GET"]))"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppEventLogger.log(
                "LOCAL_DS_HEALTH_RES \(compactJSON(["status": statusCode, "body": String(decoding: data, as: UTF8.self)]))"
            )
            return (200 ... 299).contains(statusCode)
        } catch {
            AppEventLogger.log("LOCAL_DS_HEALTH_FAIL \(error.localizedDescription)")
            return false
        }
    }

    private func translateByLocalService(_ request: TranslationRequest) async throws -> ProviderTranslationPayload {
        guard var components = URLComponents(url: localBaseURL.appendingPathComponent("query/ds"), resolvingAgainstBaseURL: false) else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local DS")
        }

        components.queryItems = [
            URLQueryItem(name: "word", value: request.sourceText),
            URLQueryItem(name: "lang", value: request.sourceLang)
        ]

        guard let url = components.url else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local DS")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 8

        AppEventLogger.log(
            "LOCAL_DS_REQ \(compactJSON(["url": url.absoluteString, "method": urlRequest.httpMethod ?? "GET", "lang": request.sourceLang, "word": request.sourceText]))"
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppEventLogger.log(
            "LOCAL_DS_RES \(compactJSON(["status": statusCode, "response": String(decoding: data, as: UTF8.self)]))"
        )
        guard (200 ... 299).contains(statusCode) else {
            throw CompletionsDictionaryHelper.ProviderError.httpError("Local DS", statusCode, String(decoding: data, as: UTF8.self))
        }

        let decoded = try JSONDecoder().decode(LocalResponse.self, from: data)
        guard decoded.code == 0, let payload = decoded.data else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local DS")
        }

        let rawTokens = payload.tokens
            .filter { !$0.k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RawWordToken(kanji: $0.k, furigana: $0.f ?? "") }

        guard !rawTokens.isEmpty else {
            throw CompletionsDictionaryHelper.ProviderError.invalidResponse("Local DS")
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
