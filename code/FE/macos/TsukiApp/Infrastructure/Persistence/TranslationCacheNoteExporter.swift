import AppKit
import Foundation
import SwiftUI

@MainActor
enum TranslationCacheNoteExporter {
    static func export(records: [SQLiteTranslationCacheStore.CachedRecord], to directory: URL) throws -> URL {
        let fileManager = FileManager.default
        let exportFolderName = "Tsuki-Export-\(LocalDateTime.runIDString())"
        let exportDirectory = directory.appendingPathComponent(exportFolderName, isDirectory: true)
        let screenshotDirectory = exportDirectory.appendingPathComponent(NoteAssetNaming.screenshotFolderName, isDirectory: true)

        try fileManager.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)

        let noteDayURL = exportDirectory.appendingPathComponent(NoteTheme.day.noteFileName, isDirectory: false)
        let noteNightURL = exportDirectory.appendingPathComponent(NoteTheme.night.noteFileName, isDirectory: false)

        let dayLabel = LocalDateTime.noteDayString()
        try "# Tsuki Note \(dayLabel) (day)\n\n".write(to: noteDayURL, atomically: true, encoding: .utf8)
        try "# Tsuki Note \(dayLabel) (night)\n\n".write(to: noteNightURL, atomically: true, encoding: .utf8)

        for record in records {
            let headword = oneLine(record.result.headwordKanji)
            let dayFileName = NoteAssetNaming.screenshotFileName(
                for: headword,
                targetLang: record.result.targetLang,
                theme: .day
            )
            let nightFileName = NoteAssetNaming.screenshotFileName(
                for: headword,
                targetLang: record.result.targetLang,
                theme: .night
            )

            if let dayImage = renderOutputCardImage(result: record.result, colorScheme: .light) {
                try savePNG(dayImage, to: screenshotDirectory.appendingPathComponent(dayFileName, isDirectory: false))
            }

            if let nightImage = renderOutputCardImage(result: record.result, colorScheme: .dark) {
                try savePNG(nightImage, to: screenshotDirectory.appendingPathComponent(nightFileName, isDirectory: false))
            }

            try appendNoteEntry(
                noteURL: noteDayURL,
                headword: headword,
                screenshotPath: "\(NoteAssetNaming.screenshotFolderName)/\(dayFileName)",
                theme: .day
            )

            try appendNoteEntry(
                noteURL: noteNightURL,
                headword: headword,
                screenshotPath: "\(NoteAssetNaming.screenshotFolderName)/\(nightFileName)",
                theme: .night
            )
        }

        return exportDirectory
    }

    private static func appendNoteEntry(
        noteURL: URL,
        headword: String,
        screenshotPath: String,
        theme: NoteTheme
    ) throws {
        var lines: [String] = []
        lines.append("### **\(headword)**")
        lines.append("")
        lines.append("<img src=\"\(screenshotPath)\" alt=\"\(headword) \(theme.rawValue)\" width=\"360\" />")
        lines.append("")
        lines.append("")
        lines.append("")

        let content = lines.joined(separator: "\n")
        guard let data = content.data(using: .utf8) else { return }

        let handle = try FileHandle(forWritingTo: noteURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private static func renderOutputCardImage(result: TranslationResult, colorScheme: ColorScheme) -> NSImage? {
        let renderWidth = DesignTokens.Size.windowWidth - (DesignTokens.Size.outerPadding * 2)
        let renderHeight = DesignTokens.Size.outputMinHeight
        let cornerRadius = DesignTokens.Size.cardRadius

        let cardView = OutputCardView(result: result, outputTitle: nil, outputMessage: nil)
            .frame(width: renderWidth, height: renderHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        let snapshotView = ZStack {
            Rectangle()
                .fill(DesignTokens.ColorToken.windowBG)
            cardView
        }
        .frame(width: renderWidth, height: renderHeight, alignment: .topLeading)
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.proposedSize = ProposedViewSize(width: renderWidth, height: renderHeight)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        return renderer.nsImage
    }

    private static func savePNG(_ image: NSImage, to url: URL) throws {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "TranslationCacheNoteExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data"])
        }

        try pngData.write(to: url, options: .atomic)
    }

    private static func oneLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
