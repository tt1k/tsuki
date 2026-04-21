import Foundation

enum TranslationNoteLogger {
    private static let queue = DispatchQueue(label: "tsuki.translation.note.logger")

    static func record(result: TranslationResult) {
        queue.async {
            let fileManager = FileManager.default
            let noteRoot = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/tsuki/note", isDirectory: true)

            let dayFolder = LocalDateTime.noteDayString()
            let noteDirectory = noteRoot.appendingPathComponent(dayFolder, isDirectory: true)

            do {
                try fileManager.createDirectory(at: noteDirectory, withIntermediateDirectories: true)

                let headword = oneLine(result.kanji)
                for theme in NoteTheme.allCases {
                    let noteURL = noteDirectory.appendingPathComponent(theme.noteFileName, isDirectory: false)
                    if !fileManager.fileExists(atPath: noteURL.path) {
                        let header = "# Tsuki Note \(dayFolder) \(theme.noteTitleSuffix)\n\n"
                        try header.write(to: noteURL, atomically: true, encoding: .utf8)
                    }

                    let screenshotPath = "\(NoteAssetNaming.screenshotFolderName)/\(NoteAssetNaming.screenshotFileName(for: headword, theme: theme))"
                    var lines: [String] = []
                    lines.append("### **\(headword)**")
                    lines.append("")
                    lines.append("<img src=\"\(screenshotPath)\" alt=\"\(headword) \(theme.noteTitleSuffix)\" width=\"360\" />")
                    lines.append("")
                    lines.append("")
                    lines.append("")

                    let line = lines.joined(separator: "\n")
                    guard let data = line.data(using: .utf8) else { return }
                    let handle = try FileHandle(forWritingTo: noteURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                }
            } catch {
                AppEventLogger.log("Failed to write translation note: \(error.localizedDescription)")
            }
        }
    }

    private static func oneLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
