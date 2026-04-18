import AppKit
import SwiftUI

enum DesignTokens {
    enum ColorToken {
        static let textMain = dynamicColor(dark: DarkColorPalette.textMain, light: LightColorPalette.textMain)
        static let textDim = dynamicColor(dark: DarkColorPalette.textDim, light: LightColorPalette.textDim)
        static let windowBG = dynamicColor(dark: DarkColorPalette.windowBG, light: LightColorPalette.windowBG)
        static let windowGlassBG = dynamicColor(dark: DarkColorPalette.windowGlassBG, light: LightColorPalette.windowGlassBG)
        static let boxIdle = dynamicColor(dark: DarkColorPalette.boxIdle, light: LightColorPalette.boxIdle)
        static let boxHover = dynamicColor(dark: DarkColorPalette.boxHover, light: LightColorPalette.boxHover)
        static let borderIdle = dynamicColor(dark: DarkColorPalette.borderIdle, light: LightColorPalette.borderIdle)
        static let borderHover = dynamicColor(dark: DarkColorPalette.borderHover, light: LightColorPalette.borderHover)
        static let caret = dynamicColor(dark: DarkColorPalette.caret, light: LightColorPalette.caret)

        static let yellow = dynamicColor(dark: DarkColorPalette.yellow, light: LightColorPalette.yellow)
        static let purple = dynamicColor(dark: DarkColorPalette.purple, light: LightColorPalette.purple)
        static let green = dynamicColor(dark: DarkColorPalette.green, light: LightColorPalette.green)
        static let blue = dynamicColor(dark: DarkColorPalette.blue, light: LightColorPalette.blue)
        static let gray = dynamicColor(dark: DarkColorPalette.gray, light: LightColorPalette.gray)

        static let translateIcon = dynamicColor(dark: DarkColorPalette.translateIcon, light: LightColorPalette.translateIcon)
        static let furigana = dynamicColor(dark: DarkColorPalette.furigana, light: LightColorPalette.furigana)
        static let controlFill = dynamicColor(dark: DarkColorPalette.controlFill, light: LightColorPalette.controlFill)
        static let windowBGNS = dynamicNSColor(dark: DarkColorPalette.windowBG, light: LightColorPalette.windowBG)
        static let windowGlassBGNS = dynamicNSColor(dark: DarkColorPalette.windowGlassBG, light: LightColorPalette.windowGlassBG)

        static func boxIdle(opacity: Double) -> Color {
            dynamicColor(
                dark: scaledColor(DarkColorPalette.boxIdle, by: opacity),
                light: scaledColor(LightColorPalette.boxIdle, by: opacity)
            )
        }

        static func boxHover(opacity: Double) -> Color {
            dynamicColor(
                dark: scaledColor(DarkColorPalette.boxHover, by: opacity),
                light: scaledColor(LightColorPalette.boxHover, by: opacity)
            )
        }

        static func borderIdle(opacity: Double) -> Color {
            dynamicColor(
                dark: scaledColor(DarkColorPalette.borderIdle, by: opacity),
                light: scaledColor(LightColorPalette.borderIdle, by: opacity)
            )
        }

        static func borderHover(opacity: Double) -> Color {
            dynamicColor(
                dark: scaledColor(DarkColorPalette.borderHover, by: opacity),
                light: scaledColor(LightColorPalette.borderHover, by: opacity)
            )
        }

        static func controlFill(opacity: Double) -> Color {
            dynamicColor(
                dark: scaledColor(DarkColorPalette.controlFill, by: opacity),
                light: scaledColor(LightColorPalette.controlFill, by: opacity)
            )
        }

        static func windowGlassBG(opacity: Double) -> Color {
            Color(nsColor: windowGlassBGNS(opacity: opacity))
        }

        static func windowGlassBGNS(opacity: Double) -> NSColor {
            let clampedOpacity = CGFloat(min(max(opacity, 0), 1))
            return dynamicNSColor(
                dark: DarkColorPalette.windowBG.withAlphaComponent(clampedOpacity),
                light: LightColorPalette.windowBG.withAlphaComponent(clampedOpacity)
            )
        }

        private static func dynamicColor(dark: NSColor, light: NSColor) -> Color {
            Color(nsColor: dynamicNSColor(dark: dark, light: light))
        }

        private static func dynamicNSColor(dark: NSColor, light: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                if match == .darkAqua {
                    return dark
                }
                return light
            }
        }

        private static func scaledColor(_ color: NSColor, by opacity: Double) -> NSColor {
            let clampedOpacity = CGFloat(min(max(opacity, 0), 1))
            return color.withAlphaComponent(color.alphaComponent * clampedOpacity)
        }
    }

    enum Size {
        static let windowWidth: CGFloat = 460
        static let windowHeight: CGFloat = 236
        static let outerPadding: CGFloat = 8
        static let cardRadius: CGFloat = 10
        static let windowRadius: CGFloat = 12
        static let cardGap: CGFloat = 8
        static let cardBorder: CGFloat = 0.5
        static let editorHeight: CGFloat = 24
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
