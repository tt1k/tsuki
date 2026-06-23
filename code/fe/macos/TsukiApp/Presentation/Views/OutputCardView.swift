import SwiftUI

struct OutputCardView: View {
    let result: TranslationResult?
    let outputTitle: String?
    let outputMessage: String?
    let cardCornerRadius: CGFloat
    let uiOpacity: Double
    let onTokenDoubleTapSearch: (String) -> Void
    let appFont: AppFontOption

    init(
        result: TranslationResult?,
        outputTitle: String?,
        outputMessage: String?,
        cardCornerRadius: CGFloat = DesignTokens.Size.cardRadius,
        uiOpacity: Double = 1,
        appFont: AppFontOption = .system,
        onTokenDoubleTapSearch: @escaping (String) -> Void = { _ in }
    ) {
        self.result = result
        self.outputTitle = outputTitle
        self.outputMessage = outputMessage
        self.cardCornerRadius = cardCornerRadius
        self.uiOpacity = uiOpacity
        self.appFont = appFont
        self.onTokenDoubleTapSearch = onTokenDoubleTapSearch
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Size.rowGap) {
            headwordRow
                .opacity((result == nil && outputTitle == nil) ? 0 : 1)

            if let outputMessage {
                Text(outputMessage)
                    .font(DesignTokens.FontToken.mono(appFont))
                    .foregroundStyle(DesignTokens.ColorToken.textDim)
            }

            FlowLayout(spacing: DesignTokens.Size.flowColumnGap, rowSpacing: DesignTokens.Size.flowRowGap) {
                ForEach(Array((result?.tokens ?? []).enumerated()), id: \.offset) { index, token in
                    WordTokenView(
                        token: token,
                        index: index,
                        appFont: appFont,
                        onDoubleTapSearch: onTokenDoubleTapSearch
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.outputMinHeight, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    DesignTokens.ColorToken.boxIdle(opacity: uiOpacity)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            DesignTokens.ColorToken.borderIdle(opacity: uiOpacity),
                            lineWidth: DesignTokens.Size.cardBorder
                        )
                }
        }
    }

    private var headwordRow: some View {
        Group {
            if let outputTitle {
                Text(outputTitle)
                    .font(DesignTokens.FontToken.monoBold(appFont))
                    .foregroundStyle(DesignTokens.ColorToken.textMain)
            } else if let result {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(result.kanji)
                            .font(DesignTokens.FontToken.monoBold(appFont))
                            .foregroundStyle(DesignTokens.ColorToken.textMain)
                        Text(result.kana)
                            .font(DesignTokens.FontToken.monoBold(appFont))
                            .foregroundStyle(DesignTokens.ColorToken.textDim)
                    }

                    if !result.meaning.isEmpty {
                        Text(result.meaning)
                            .font(DesignTokens.FontToken.meaning(appFont))
                            .foregroundStyle(DesignTokens.ColorToken.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(" ")
                    .font(DesignTokens.FontToken.monoBold(appFont))
            }
        }
    }
}
