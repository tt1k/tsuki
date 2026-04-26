import SwiftUI
import AppKit

struct WordTokenView: View {
    let token: WordToken
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Text(shouldShowFurigana ? token.furigana : "")
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
        .background {
            if isCopyable && isHovered {
                RoundedRectangle(cornerRadius: DesignTokens.Size.capsuleRadius, style: .continuous)
                    .fill(DesignTokens.ColorToken.borderHover)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -2)
            }
        }
        .background(alignment: .bottom) {
            if shouldShowUnderline {
                RoundedRectangle(cornerRadius: DesignTokens.Size.capsuleRadius, style: .continuous)
                    .fill(capsuleColor)
                    .frame(height: DesignTokens.Size.capsuleHeight)
                    .offset(y: -1.5)
                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
            }
        }
        .onTapGesture(count: 2) {
            copyTokenIfNeeded()
        }
        .onTapGesture {
            copyTokenIfNeeded()
        }
        .onHover { hovering in
            guard isCopyable else { return }
            isHovered = hovering
            if hovering {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
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

    private var isCopyable: Bool {
        !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func copyTokenIfNeeded() {
        guard isCopyable else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token.kanji, forType: .string)
    }

    private var shouldShowUnderline: Bool {
        let surface = token.kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !surface.isEmpty else { return false }
        guard !isPunctuationOrSymbolOrWhitespaceOnly(surface) else { return false }
        guard !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return containsKanjiCharacter(in: surface)
    }

    private var shouldShowFurigana: Bool {
        shouldShowUnderline
    }

    private func containsKanjiCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(scalar.value)
                || (0x3400 ... 0x4DBF).contains(scalar.value)
                || scalar.value == 0x3005
                || scalar.value == 0x3006
                || scalar.value == 0x30F6
        }
    }

    private func isPunctuationOrSymbolOrWhitespaceOnly(_ text: String) -> Bool {
        let japanesePunctuation = CharacterSet(charactersIn: "、。！？「」『』（）［］【】〈〉《》・…〜～")
        return text.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar)
                || japanesePunctuation.contains(scalar)
        }
    }
}
