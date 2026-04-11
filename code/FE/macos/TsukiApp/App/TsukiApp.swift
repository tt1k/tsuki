import SwiftUI

@main
struct TsukiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: MainViewModel

    init() {
        AppEventLogger.configureFromLaunchArguments()

        let settingsStore = SettingsStore()
        let viewModel = MainViewModel(
            translationUseCase: TranslationUseCase(
                translatorProvider: TranslateRouterProvider(),
                tokenizeAndAnnotateUseCase: TokenizeAndAnnotateUseCase(),
                translationCacheStore: SQLiteTranslationCacheStore()
            ),
            settingsStore: settingsStore
        )

        _settingsStore = StateObject(wrappedValue: settingsStore)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some Scene {
        Window("Tsuki", id: "main-window") {
            MainWindowView(viewModel: viewModel)
                .environmentObject(settingsStore)
                .preferredColorScheme(settingsStore.appearanceMode.preferredColorScheme)
                .frame(width: DesignTokens.Size.windowWidth, height: DesignTokens.Size.windowHeight)
                .onAppear {
                    appDelegate.applyDockIconVisibility(settingsStore.dockIconVisible)
                    appDelegate.configureWindowIfNeeded(
                        forceTopRightOnLaunch: true,
                        appearanceMode: settingsStore.appearanceMode
                    )
                }
                .onChange(of: settingsStore.appearanceMode) { mode in
                    appDelegate.applyAppearanceMode(mode)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
