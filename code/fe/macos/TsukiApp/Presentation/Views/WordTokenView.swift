import SwiftUI

struct WordTokenView: View {
    let token: WordToken
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(token.furigana)
                .font(DesignTokens.FontToken.furigana)
                .foregroundStyle(DesignTokens.ColorToken.furigana)
                .lineLimit(1)
                .frame(height: 10)

            Text(token.kanji)
                .font(DesignTokens.FontToken.mono)
                .foregroundStyle(DesignTokens.ColorToken.textMain)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .background(alignment: .bottom) {
            RoundedRectangle(cornerRadius: DesignTokens.Size.capsuleRadius, style: .continuous)
                .fill(capsuleColor)
                .frame(height: DesignTokens.Size.capsuleHeight)
                .offset(y: -1.5)
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
        }
    }

    private var capsuleColor: Color {
        switch token.highlight {
        case .yellow: return DesignTokens.ColorToken.yellow
        case .purple: return DesignTokens.ColorToken.purple
        case .green: return DesignTokens.ColorToken.green
        case .blue: return DesignTokens.ColorToken.blue
        case .gray: return DesignTokens.ColorToken.gray
        }
    }
}
