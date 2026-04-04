import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    enum State {
        case idle
        case typing
        case translating
        case success(TranslationResult)
        case failure(String)
    }

    @Published var inputText: String = MockSeedData.requestText {
        didSet {
            if case .translating = state {
                task?.cancel()
            }
            if inputText.isEmpty {
                state = .idle
            } else {
                state = .typing
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published var showSettings = false

    private let translationUseCase: TranslationUseCase
    private var task: Task<Void, Never>?

    init(translationUseCase: TranslationUseCase) {
        self.translationUseCase = translationUseCase
    }

    var result: TranslationResult? {
        if case let .success(result) = state {
            return result
        }
        return nil
    }

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state = .failure("请输入要翻译的文本")
            return
        }

        task?.cancel()
        state = .translating

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await translationUseCase.execute(
                    request: TranslationRequest(sourceText: text, sourceLang: "zh", targetLang: "ja")
                )
                guard !Task.isCancelled else { return }
                state = .success(result)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failure("翻译失败，请稍后重试")
            }
        }
    }
}
