import SwiftUI

struct OutputCardView: View {
    let result: TranslationResult?
    let outputTitle: String?
    let outputMessage: String?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Size.rowGap) {
            headwordRow
                .opacity((result == nil && outputTitle == nil) ? 0 : 1)

            if let outputMessage {
                Text(outputMessage)
                    .font(DesignTokens.FontToken.mono)
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
            }

            FlowLayout(spacing: DesignTokens.Size.flowColumnGap, rowSpacing: DesignTokens.Size.flowRowGap) {
                ForEach(result?.tokens ?? []) { token in
                    WordTokenView(token: token)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.outputMinHeight, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
                .fill(isHovered ? DesignTokens.ColorToken.boxHover : DesignTokens.ColorToken.boxIdle)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Size.cardRadius, style: .continuous)
                        .stroke(isHovered ? DesignTokens.ColorToken.borderHover : DesignTokens.ColorToken.borderIdle, lineWidth: DesignTokens.Size.cardBorder)
                }
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Motion.hover) {
                isHovered = hovering
            }
        }
    }

    private var headwordRow: some View {
        Group {
            if let outputTitle {
                Text(outputTitle)
                    .font(DesignTokens.FontToken.monoBold)
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
            } else if let result {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(result.headwordKanji)
                            .font(DesignTokens.FontToken.monoBold)
                            .foregroundStyle(DesignTokens.ColorToken.textMain)
                        Text(result.headwordKana)
                            .font(DesignTokens.FontToken.monoBold)
                            .foregroundStyle(DesignTokens.ColorToken.textDim)
                    }

                    if !result.meaning.isEmpty {
                        Text(result.meaning)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(DesignTokens.ColorToken.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(" ")
                    .font(DesignTokens.FontToken.monoBold)
            }
        }
    }
}
