import Foundation
import Combine

@MainActor
final class MainViewModel: ObservableObject {
    private let maxInputCharacters = 25

    enum State {
        case idle
        case typing
        case success(TranslationResult)
        case failure(title: String, message: String)
    }

    @Published var inputText: String {
        didSet {
            guard inputText != oldValue else {
                return
            }

            if inputText.isEmpty {
                state = .idle
            } else {
                state = .typing
            }

            clearInputOverflowNotice()
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isTranslating = false
    @Published private(set) var inputLimitNoticeTitle: String?
    @Published private(set) var inputLimitNotice: String?
    @Published var showSettings = false

    private var displayedResult: TranslationResult?
    private var displayedError: (title: String, message: String)?

    private let translationUseCase: TranslationUseCase
    private let settingsStore: SettingsStore
    private var languageObserver: AnyCancellable?
    private var latestRequestID: UInt64 = 0
    private var requestIDSeed: UInt64 = 0

    init(translationUseCase: TranslationUseCase, settingsStore: SettingsStore) {
        self.translationUseCase = translationUseCase
        self.settingsStore = settingsStore
        self.inputText = Self.defaultInputText(for: settingsStore.language)

        languageObserver = settingsStore.$language
            .removeDuplicates()
            .sink { [weak self] language in
                self?.applyDefaultInputIfNeeded(for: language)
            }
    }

    var result: TranslationResult? {
        displayedResult
    }

    var errorMessage: String? {
        displayedError?.message
    }

    var errorTitle: String? {
        displayedError?.title
    }

    var outputTitle: String? {
        errorTitle ?? inputLimitNoticeTitle
    }

    var outputMessage: String? {
        errorMessage ?? inputLimitNotice
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            let failure = localizedFailureState(
                title: localizedText(
                    en: "Input Required",
                    zhCN: "需要输入",
                    zhTW: "需要輸入",
                    ja: "入力が必要です"
                ),
                message: localizedText(
                    en: "Please enter text to translate",
                    zhCN: "请输入要翻译的内容",
                    zhTW: "請輸入要翻譯的內容",
                    ja: "翻訳するテキストを入力してください"
                )
            )
            applyFailure(failure)
            return
        }

        guard text.count <= maxInputCharacters else {
            let failure = localizedFailureState(
                title: localizedText(
                    en: "Input Too Long",
                    zhCN: "输入过长",
                    zhTW: "輸入過長",
                    ja: "入力が長すぎます"
                ),
                message: localizedText(
                    en: "Input exceeds 25 characters. Please shorten it before translating.",
                    zhCN: "输入超过 25 个字，请精简后再翻译",
                    zhTW: "輸入超過 25 個字，請精簡後再翻譯",
                    ja: "入力が25文字を超えています；短くしてから翻訳してください"
                )
            )
            applyFailure(failure)
            return
        }

        requestIDSeed &+= 1
        let requestID = requestIDSeed
        latestRequestID = requestID
        isTranslating = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await translationUseCase.execute(
                    request: TranslationRequest(
                        sourceText: text,
                        provider: settingsStore.provider,
                        apiKey: settingsStore.apiKey(for: settingsStore.provider),
                        sourceLang: settingsStore.language,
                        targetLang: "ja"
                    )
                )
                guard requestID == latestRequestID else { return }
                state = .success(result)
                displayedResult = result
                displayedError = nil
                TranslationNoteLogger.record(result: result)
            } catch {
                guard requestID == latestRequestID else { return }
                let failure = localizedFailureState(for: error)
                applyFailure(failure)
            }

            if requestID == latestRequestID {
                isTranslating = false
            }
        }
    }

    func notifyInputOverflow() {
        let title = localizedText(
            en: "Input Too Long",
            zhCN: "输入过长",
            zhTW: "輸入過長",
            ja: "入力が長すぎます"
        )

        let notice = localizedText(
            en: "Input exceeds 25 characters. You can keep editing, but translation requests will be blocked until shortened.",
            zhCN: "输入超过 25 个字；你仍可继续编辑，但发起翻译时会被拦截，请先精简",
            zhTW: "輸入超過 25 個字；你仍可繼續編輯，但發起翻譯時會被攔截，請先精簡",
            ja: "入力が25文字を超えています；編集は続けられますが、翻訳リクエストは短くするまでブロックされます"
        )

        if inputLimitNoticeTitle != title {
            inputLimitNoticeTitle = title
        }

        if inputLimitNotice != notice {
            inputLimitNotice = notice
        }
    }

    func clearInputOverflowNotice() {
        if inputLimitNoticeTitle != nil || inputLimitNotice != nil {
            inputLimitNoticeTitle = nil
            inputLimitNotice = nil
        }
    }

    private func applyFailure(_ failure: State) {
        state = failure
        if case let .failure(title, message) = failure {
            displayedError = (title: title, message: message)
            displayedResult = nil
        }
    }

    private func localizedFailureState(title: String, message: String) -> State {
        .failure(title: title, message: message)
    }

    private func localizedFailureState(for error: Error) -> State {
        if error is CompletionsDictionaryHelper.ProviderError {
            switch error as? CompletionsDictionaryHelper.ProviderError {
            case let .missingAPIKey(providerName):
                return localizedFailureState(
                    title: localizedText(en: "API Key Missing", zhCN: "缺少 API Key", zhTW: "缺少 API Key", ja: "APIキー未設定"),
                    message: localizedText(
                        en: "Set an API key for \(providerName) in Settings.",
                        zhCN: "请在 Settings 中为 \(providerName) 配置 API Key",
                        zhTW: "請在 Settings 中為 \(providerName) 設定 API Key",
                        ja: "Settings で \(providerName) の API キーを設定してください"
                    )
                )
            case .invalidResponse:
                return localizedFailureState(
                    title: localizedText(en: "Invalid Response", zhCN: "响应异常", zhTW: "回應異常", ja: "応答形式エラー"),
                    message: localizedText(
                        en: "The provider returned an invalid response format.",
                        zhCN: "模型返回了无法解析的响应格式",
                        zhTW: "模型回傳了無法解析的回應格式",
                        ja: "プロバイダーの応答形式を解析できませんでした"
                    )
                )
            case let .httpError(providerName, code, _):
                return localizedFailureState(
                    title: localizedText(en: "Request Failed", zhCN: "请求失败", zhTW: "請求失敗", ja: "リクエスト失敗"),
                    message: localizedText(
                        en: "\(providerName) API request failed (HTTP \(code)).",
                        zhCN: "\(providerName) 请求失败（HTTP \(code)）",
                        zhTW: "\(providerName) 請求失敗（HTTP \(code)）",
                        ja: "\(providerName) API リクエストに失敗しました（HTTP \(code)）"
                    )
                )
            case nil:
                break
            }
        }

        if let providerError = error as? TranslateRouterProvider.ProviderError {
            switch providerError {
            case let .unsupportedProvider(provider):
                return localizedFailureState(
                    title: localizedText(en: "Provider Not Supported", zhCN: "模型暂不支持", zhTW: "模型暫不支援", ja: "プロバイダー未対応"),
                    message: localizedText(
                        en: "Provider '\(provider)' is not supported yet.",
                        zhCN: "当前模型 '\(provider)' 暂未接入",
                        zhTW: "目前模型 '\(provider)' 尚未接入",
                        ja: "プロバイダー '\(provider)' はまだサポートされていません"
                    )
                )
            }
        }

        return localizedFailureState(
            title: localizedText(en: "Translation Failed", zhCN: "翻译失败", zhTW: "翻譯失敗", ja: "翻訳失敗"),
            message: localizedText(
                en: "Translation failed, please try again",
                zhCN: "翻译失败，请稍后重试",
                zhTW: "翻譯失敗，請稍後再試",
                ja: "翻訳に失敗しました；しばらくしてから再試行してください"
            )
        )
    }

    private func localizedText(en: String, zhCN: String, zhTW: String, ja: String) -> String {
        switch settingsStore.language {
        case "zh-CN": return zhCN
        case "zh-TW": return zhTW
        case "ja": return ja
        default: return en
        }
    }

    private static func defaultInputText(for language: String) -> String {
        switch language {
        case "zh-CN": "我能帮什么忙吗"
        case "zh-TW": "我們該從哪裡開始"
        case "ja": "どこから始めますか"
        case "ko": "어디서부터 시작할까요"
        case "es": "¿Por dónde empezamos"
        case "fr": "Par où commence-t-on"
        case "de": "Wo fangen wir an"
        case "ru": "С чего начнем"
        default: "How can I help"
        }
    }

    private static func isDefaultInputText(_ text: String) -> Bool {
        let presets = ["zh-CN", "zh-TW", "en", "ja", "ko", "es", "fr", "de", "ru"].map(defaultInputText(for:))
        return presets.contains(text)
    }

    private func applyDefaultInputIfNeeded(for language: String) {
        let current = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard current.isEmpty || Self.isDefaultInputText(current) else { return }
        inputText = Self.defaultInputText(for: language)
    }
}
