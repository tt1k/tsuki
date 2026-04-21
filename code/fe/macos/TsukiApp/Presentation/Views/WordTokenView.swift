import SwiftUI

struct WordTokenView: View {
    let token: WordToken
    let index: Int
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
        let colors: [Color] = [
            DesignTokens.ColorToken.yellow,
            DesignTokens.ColorToken.purple,
            DesignTokens.ColorToken.green,
            DesignTokens.ColorToken.blue,
            DesignTokens.ColorToken.gray
        ]
        let seedText = token.kanji + token.furigana + String(index)
        let seed = seedText.unicodeScalars.reduce(UInt64(0)) { partial, scalar in
            (partial &* 31) &+ UInt64(scalar.value)
        }
        return colors[Int(seed % UInt64(colors.count))]
    }
}
