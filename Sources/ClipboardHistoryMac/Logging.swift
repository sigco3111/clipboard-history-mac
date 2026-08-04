import Foundation
import os.log

enum AppLog {
    private static let logger = Logger(subsystem: "com.clipboard-history-mac", category: "app")
    private static let logFileURL: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ClipboardHistoryMac.log")
    }()

    nonisolated static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        appendToFile("[INFO] " + message)
    }

    nonisolated static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        appendToFile("[ERROR] " + message)
    }

    private static let writeQueue = DispatchQueue(label: "app-log-write")
    private static func appendToFile(_ line: String) {
        writeQueue.sync {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let entry = "\(timestamp) \(line)\n"
            guard let data = entry.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    static func logFilePath() -> String { logFileURL.path }
}
