import Foundation
import AppKit
import XCTest
@testable import ClipboardHistoryMac

@MainActor
enum TestStorageFactory {
    static func makeStorage(suffix: String = UUID().uuidString) -> StorageManager {
        let tmp = makeDir(suffix: suffix)
        return StorageManager(baseDirectory: tmp)
    }

    static func makeStorage(baseDirectory: URL) -> StorageManager {
        return StorageManager(baseDirectory: baseDirectory)
    }

    private static func makeDir(suffix: String) -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("clipboard-history-test-\(suffix)", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }
}
