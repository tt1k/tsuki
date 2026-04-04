import SwiftUI

enum DesignTokens {
    enum ColorToken {
        static let textMain = Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
        static let textDim = Color(red: 119 / 255, green: 119 / 255, blue: 119 / 255)
        static let windowBG = Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255).opacity(0.98)
        static let boxIdle = Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255).opacity(0.5)
        static let boxHover = Color(red: 60 / 255, green: 60 / 255, blue: 60 / 255).opacity(0.75)
        static let borderIdle = Color.white.opacity(0.04)
        static let borderHover = Color.white.opacity(0.12)
        static let caret = Color.white

        static let yellow = Color(red: 204 / 255, green: 171 / 255, blue: 8 / 255).opacity(0.45)
        static let purple = Color(red: 153 / 255, green: 72 / 255, blue: 194 / 255).opacity(0.45)
        static let green = Color(red: 40 / 255, green: 172 / 255, blue: 60 / 255).opacity(0.45)
        static let blue = Color(red: 8 / 255, green: 105 / 255, blue: 204 / 255).opacity(0.45)
        static let gray = Color(red: 110 / 255, green: 110 / 255, blue: 115 / 255).opacity(0.4)

        static let translateIcon = Color(red: 50 / 255, green: 215 / 255, blue: 75 / 255).opacity(0.6)
        static let furigana = Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255)
    }

    enum Size {
        static let windowWidth: CGFloat = 460
        static let outerPadding: CGFloat = 8
        static let cardRadius: CGFloat = 10
        static let windowRadius: CGFloat = 12
        static let cardGap: CGFloat = 8
        static let cardBorder: CGFloat = 0.5
        static let editorHeight: CGFloat = 90
        static let outputMinHeight: CGFloat = 160
        static let rowGap: CGFloat = 14
        static let flowRowGap: CGFloat = 12
        static let flowColumnGap: CGFloat = 5
        static let capsuleHeight: CGFloat = 5.5
        static let capsuleRadius: CGFloat = 4
    }

    enum FontToken {
        static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let monoBold = Font.system(size: 14, weight: .heavy, design: .monospaced)
        static let furigana = Font.system(size: 8.5, weight: .regular, design: .monospaced)
        static let icon = Font.system(size: 14, weight: .regular)
    }

    enum Motion {
        static let hover = Animation.easeInOut(duration: 0.25)
    }
}
