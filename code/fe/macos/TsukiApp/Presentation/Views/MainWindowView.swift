import AppKit
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: DesignTokens.Size.cardGap) {
            InputCardView(
                inputText: $viewModel.inputText,
                isTranslating: viewModel.isTranslating,
                onTranslate: {
                    AppEventLogger.log("User clicked translate button")
                    viewModel.translate()
                },
                onSettings: {
                    AppEventLogger.log("User opened settings")
                    guard let appDelegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate) else {
                        AppEventLogger.log("Failed to open settings: AppDelegate unavailable")
                        return
                    }
                    appDelegate.showSettingsWindow(settingsStore: settingsStore)
                },
                onInputOverflow: {
                    viewModel.notifyInputOverflow()
                },
                onInputWithinLimit: {
                    viewModel.clearInputOverflowNotice()
                }
            )

            OutputCardView(
                result: viewModel.result,
                outputTitle: viewModel.outputTitle,
                outputMessage: viewModel.outputMessage,
                uiOpacity: settingsStore.windowGlassOpacity
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, DesignTokens.Size.outerPadding)
        .padding(.vertical, DesignTokens.Size.outerPadding)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Size.windowRadius, style: .continuous)
                .fill(DesignTokens.ColorToken.windowGlassBG(opacity: settingsStore.windowGlassOpacity))
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Size.windowRadius, style: .continuous))
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .triggerTranslate)) { _ in
            AppEventLogger.log("Enter translate shortcut received")
            viewModel.translate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fillInputAndTranslate)) { notification in
            guard let text = notification.object as? String else { return }
            viewModel.inputText = text
            viewModel.translate()
        }
        .onChangeCompat(of: viewModel.isTranslating) { translating in
            guard !translating, let result = viewModel.result else { return }
            saveOutputCardScreenshot(result: result)
        }
        .onExitCommand {
            NSApp.hide(nil)
        }
    }

    private func saveOutputCardScreenshot(result: TranslationResult) {
        let renderWidth = DesignTokens.Size.windowWidth - (DesignTokens.Size.outerPadding * 2)
        let renderHeight = DesignTokens.Size.outputMinHeight

        var images: [NoteTheme: NSImage] = [:]
        images[.day] = renderOutputCardImage(
            result: result,
            colorScheme: .light,
            renderWidth: renderWidth,
            renderHeight: renderHeight
        )
        images[.night] = renderOutputCardImage(
            result: result,
            colorScheme: .dark,
            renderWidth: renderWidth,
            renderHeight: renderHeight
        )

        let validImages = images.compactMapValues { $0 }
        guard !validImages.isEmpty else {
            AppEventLogger.log("Failed to render output card screenshot")
            return
        }

        OutputCardScreenshotWriter.save(
            images: validImages,
            japaneseWord: result.kanji
        )
    }

    private func renderOutputCardImage(
        result: TranslationResult,
        colorScheme: ColorScheme,
        renderWidth: CGFloat,
        renderHeight: CGFloat
    ) -> NSImage? {
        let cardView = OutputCardView(
            result: result,
            outputTitle: nil,
            outputMessage: nil,
            cardCornerRadius: 0
        )
            .frame(width: renderWidth, height: renderHeight, alignment: .topLeading)

        let snapshotView = ZStack {
            Rectangle()
                .fill(DesignTokens.ColorToken.windowBG)
            cardView
        }
        .frame(width: renderWidth, height: renderHeight, alignment: .topLeading)
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.proposedSize = ProposedViewSize(width: renderWidth, height: renderHeight)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        return renderer.nsImage
    }
}
