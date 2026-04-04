import SwiftUI

struct InputCardView: View {
    @Binding var inputText: String
    let state: MainViewModel.State
    let onTranslate: () -> Void
    let onSettings: () -> Void

    @FocusState private var focused: Bool
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground

            TextEditor(text: $inputText)
                .scrollContentBackground(.hidden)
                .font(DesignTokens.FontToken.mono)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .frame(height: DesignTokens.Size.editorHeight)
                .padding(.top, 8)
                .padding(.leading, 12)
                .padding(.trailing, 66)
                .padding(.bottom, 8)
                .focused($focused)

            HStack(spacing: 8) {
                iconButton(symbol: "translate", color: DesignTokens.ColorToken.translateIcon, action: onTranslate)
                iconButton(symbol: "gearshape", color: DesignTokens.ColorToken.textDim, action: onSettings)
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Motion.hover) {
                isHovered = hovering
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusInput)) { _ in
            focused = true
        }
        .onAppear {
            DispatchQueue.main.async {
                focused = true
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
            .fill(isHovered ? DesignTokens.ColorToken.boxHover : DesignTokens.ColorToken.boxIdle)
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
                    .stroke(isHovered ? DesignTokens.ColorToken.borderHover : DesignTokens.ColorToken.borderIdle, lineWidth: DesignTokens.Size.cardBorder)
            }
    }

    private func iconButton(symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(DesignTokens.FontToken.icon)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
