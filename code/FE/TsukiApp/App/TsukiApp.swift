import SwiftUI

@main
struct TsukiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = MainViewModel(
        translationUseCase: TranslationUseCase(
            translatorProvider: MockTranslationProvider(),
            tokenizeAndAnnotateUseCase: TokenizeAndAnnotateUseCase(tokenizerProvider: NaturalLanguageTokenizerProvider())
        )
    )

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: viewModel)
                .frame(width: DesignTokens.Size.windowWidth)
                .onAppear {
                    appDelegate.configureWindowIfNeeded()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
