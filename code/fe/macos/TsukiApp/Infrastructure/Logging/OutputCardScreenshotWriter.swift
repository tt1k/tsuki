import AppKit
import Foundation

enum OutputCardScreenshotWriter {
    static func save(images: [NoteTheme: NSImage], japaneseWord: String) {
        let fileManager = FileManager.default
        let noteDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/tsuki/note", isDirectory: true)
            .appendingPathComponent(LocalDateTime.noteDayString(), isDirectory: true)
        let screenshotDirectory = noteDirectory
            .appendingPathComponent(NoteAssetNaming.screenshotFolderName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)

            for (theme, image) in images {
                let outputURL = screenshotDirectory
                    .appendingPathComponent(
                        NoteAssetNaming.screenshotFileName(for: japaneseWord, theme: theme),
                        isDirectory: false
                    )

                guard
                    let tiffData = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmap.representation(using: .png, properties: [:])
                else {
                    AppEventLogger.log("Failed to encode output card screenshot as PNG")
                    continue
                }

                try pngData.write(to: outputURL, options: .atomic)
            }
        } catch {
            AppEventLogger.log("Failed to save output card screenshot: \(error.localizedDescription)")
        }
    }
}
