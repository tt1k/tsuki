import Foundation

enum NoteTheme: String, CaseIterable {
    case day
    case night

    var noteFileName: String {
        "NOTE-\(rawValue).md"
    }

    var noteTitleSuffix: String {
        switch self {
        case .day:
            return "Light"
        case .night:
            return "Dark"
        }
    }
}

enum NoteAssetNaming {
    static let screenshotFolderName = "screenshot"

    static func screenshotFileName(for japaneseWord: String, targetLang: String, theme: NoteTheme) -> String {
        "\(sanitizeFileName(japaneseWord))-\(sanitizeFileName(targetLang))-\(theme.rawValue).png"
    }

    private static func sanitizeFileName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "word"
        }

        let invalid = CharacterSet(charactersIn: "/\\?%*|\":<>")
        let sanitizedScalars = trimmed.unicodeScalars.map { scalar -> UnicodeScalar in
            invalid.contains(scalar) ? "_" : scalar
        }
        let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
        return sanitized.isEmpty ? "word" : sanitized
    }
}
