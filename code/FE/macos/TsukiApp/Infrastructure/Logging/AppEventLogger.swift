import Foundation

enum AppEventLogger {
    private static let queue = DispatchQueue(label: "tsuki.app.logger")
    private static var logURL: URL?

    static func configureFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/tsuki", isDirectory: true)
        let runID: String

        if
            let runIndex = arguments.firstIndex(of: "--run-id"),
            arguments.indices.contains(runIndex + 1)
        {
            runID = arguments[runIndex + 1]
        } else {
            runID = defaultRunID()
        }

        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            logURL = logsDir.appendingPathComponent("tsuki-app-\(runID).log", isDirectory: false)
            log("Logger initialized")
        } catch {
            logURL = nil
        }
    }

    private static func defaultRunID() -> String {
        LocalDateTime.runIDString()
    }

    static func log(_ message: String) {
        queue.async {
            guard let logURL else { return }

            let line = "[\(LocalDateTime.logTimestampString())] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }

            do {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                return
            }
        }
    }

    static func currentLogPath() -> String? {
        queue.sync {
            logURL?.path
        }
    }

    static func currentLogDirectoryPath() -> String? {
        queue.sync {
            logURL?.deletingLastPathComponent().path
        }
    }
}
