import SwiftUI
import AppKit

struct WordTokenView: View {
    let token: WordToken
    let index: Int
    let onDoubleTapSearch: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Text(annotationText)
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
            triggerDoubleTapSearchIfNeeded()
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
        let surface = token.kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !surface.isEmpty else { return false }
        guard !isPunctuationOrSymbolOrWhitespaceOnly(surface) else { return false }

        if containsKanjiCharacter(in: surface) {
            return !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return isKatakanaWord(surface)
    }

    private func copyTokenIfNeeded() {
        guard isCopyable else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token.kanji, forType: .string)
    }

    private func triggerDoubleTapSearchIfNeeded() {
        guard isCopyable else { return }
        onDoubleTapSearch(token.kanji)
    }

    private var shouldShowUnderline: Bool {
        let surface = token.kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !surface.isEmpty else { return false }
        guard !isPunctuationOrSymbolOrWhitespaceOnly(surface) else { return false }

        if containsKanjiCharacter(in: surface) {
            return !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return isKatakanaWord(surface)
    }

    private var shouldShowFurigana: Bool {
        let surface = token.kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        return containsKanjiCharacter(in: surface)
            && !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var annotationText: String {
        let surface = token.kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsKanjiCharacter(in: surface),
           !token.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return token.furigana
        }

        if isKatakanaWord(surface),
           let annotation = token.annotation?.trimmingCharacters(in: .whitespacesAndNewlines),
           !annotation.isEmpty {
            return annotation
        }

        return ""
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

    private func isKatakanaWord(_ text: String) -> Bool {
        text.unicodeScalars.contains { isKatakanaScalar($0) }
            && text.unicodeScalars.allSatisfy { scalar in
                isKatakanaScalar(scalar) || scalar.value == 0x30FC || scalar.value == 0x30FB
            }
    }

    private func isKatakanaScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x30A0 ... 0x30FF).contains(scalar.value)
            || (0x31F0 ... 0x31FF).contains(scalar.value)
            || (0xFF66 ... 0xFF9D).contains(scalar.value)
    }
}
