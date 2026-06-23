import SwiftUI

enum AppFontOption: String, CaseIterable, Codable {
    case system
    case zenAntiqueSoft = "zen_antique_soft"
    case notoSerifJP = "noto_serif_jp"

    var regularFontName: String? {
        switch self {
        case .system:
            return nil
        case .zenAntiqueSoft:
            return "ZenAntiqueSoft-Regular"
        case .notoSerifJP:
            return "NotoSerifJP-Regular"
        }
    }

    var boldFontName: String? {
        switch self {
        case .system:
            return nil
        case .zenAntiqueSoft:
            return "ZenAntiqueSoft-Regular"
        case .notoSerifJP:
            return "NotoSerifJP-Bold"
        }
    }

    func regular(size: CGFloat) -> Font {
        if let regularFontName {
            return Font.custom(regularFontName, size: size)
        }
        return .system(size: size, weight: .regular, design: .default)
    }

    func bold(size: CGFloat) -> Font {
        if let boldFontName {
            return Font.custom(boldFontName, size: size)
        }
        return .system(size: size, weight: .heavy, design: .default)
    }
}
