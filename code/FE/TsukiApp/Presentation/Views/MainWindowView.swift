import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: DesignTokens.Size.cardGap) {
            InputCardView(
                inputText: $viewModel.inputText,
                state: viewModel.state,
                onTranslate: { viewModel.translate() },
                onSettings: { viewModel.showSettings = true }
            )

            OutputCardView(result: viewModel.result)
        }
        .padding(DesignTokens.Size.outerPadding)
        .background {
            ZStack {
                VisualEffectView(material: .ultraDark)
                RoundedRectangle(cornerRadius: DesignTokens.Size.windowRadius, style: .continuous)
                    .fill(DesignTokens.ColorToken.windowBG)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Size.windowRadius, style: .continuous)
                .stroke(DesignTokens.ColorToken.borderIdle, lineWidth: DesignTokens.Size.cardBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Size.windowRadius, style: .continuous))
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsSheetView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerTranslate)) { _ in
            viewModel.translate()
        }
    }
}
