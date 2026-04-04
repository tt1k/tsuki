import SwiftUI

struct OutputCardView: View {
    let result: TranslationResult?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Size.rowGap) {
            headwordRow
                .opacity(result == nil ? 0 : 1)

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
            if let result {
                HStack(spacing: 8) {
                    Text(result.headwordKanji)
                        .font(DesignTokens.FontToken.monoBold)
                        .foregroundStyle(DesignTokens.ColorToken.textMain)
                    Text(result.headwordKana)
                        .font(DesignTokens.FontToken.monoBold)
                        .foregroundStyle(DesignTokens.ColorToken.textDim)
                }
            } else {
                Text(" ")
                    .font(DesignTokens.FontToken.monoBold)
            }
        }
    }
}
