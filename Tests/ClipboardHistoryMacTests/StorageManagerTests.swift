import Foundation
import AppKit
import CryptoKit
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class StorageManagerTests: XCTestCase {

    func testAddImagePersistsAcrossNewInstance() throws {
        let storageA = TestStorageFactory.makeStorage(suffix: "image-roundtrip")
        let payload = Data(repeating: 0xAB, count: 1024)
        let id = storageA.addImage(data: payload, mime: "image/png")
        XCTAssertGreaterThan(id, 0)

        let storageB = TestStorageFactory.makeStorage(baseDirectory: storageA.baseDirectory)
        XCTAssertEqual(storageB.entries.count, 1)
        let entry = try XCTUnwrap(storageB.entries.first)
        XCTAssertEqual(entry.type, "image")
        XCTAssertEqual(entry.hash, sha256Hex(payload))
        XCTAssertEqual(entry.size, payload.count)

        let url = storageB.imageURL(filename: try XCTUnwrap(entry.imageFilename))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let loaded = try Data(contentsOf: url)
        XCTAssertEqual(loaded, payload)
    }

    func testAddTextAndHasText() {
        let storage = TestStorageFactory.makeStorage(suffix: "text")
        storage.addText("hello world")
        XCTAssertEqual(storage.entries.count, 1)
        XCTAssertEqual(storage.entries.first?.type, "text")
        XCTAssertTrue(storage.hasText(hash: sha256Hex(Data("hello world".utf8))))
    }

    func testAddImageDedupedByHash() {
        let storage = TestStorageFactory.makeStorage(suffix: "image-dedup")
        let payload = Data([0, 1, 2, 3, 4, 5])
        let id1 = storage.addImage(data: payload, mime: "image/png")
        let id2 = storage.addImage(data: payload, mime: "image/png")
        XCTAssertEqual(storage.entries.count, 1)
        XCTAssertEqual(id1, id2)
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class StorageDeleteTests: XCTestCase {

    /// Required for the per-row "Delete" button. StorageManager.delete removes the
    /// entry from `entries` and removes the on-disk image file for image entries.
    func testDeleteTextEntry() {
        let storage = TestStorageFactory.makeStorage(suffix: "delete-text")
        storage.addText("hello-delete-me")
        XCTAssertEqual(storage.entries.count, 1)
        let target = storage.entries[0]
        storage.delete(target)
        XCTAssertEqual(storage.entries.count, 0)
    }

    func testDeleteImageEntryRemovesFile() throws {
        let storage = TestStorageFactory.makeStorage(suffix: "delete-image")
        let payload = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let id = storage.addImage(data: payload, mime: "image/png")
        XCTAssertEqual(storage.entries.count, 1)
        let imageEntry = try XCTUnwrap(storage.entries.first { $0.id == id })
        let url = storage.imageURL(filename: try XCTUnwrap(imageEntry.imageFilename))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "image file must exist before delete")

        storage.delete(imageEntry)

        XCTAssertEqual(storage.entries.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "image file must be removed after delete")
    }

    func testRowLayoutHasCopyAndDeleteButtons() throws {
        let src = try String(contentsOfFile: "/Users/mac/work/github/clipboard-history-mac/Sources/ClipboardHistoryMac/MainWindowView.swift", encoding: .utf8)

        // Per-row delete button: image must reference trash
        let rowStart = src.range(of: "struct EntryRow")!
        // EntryRow is the last struct in the file; bound to end of file.
        let rowBody = String(src[rowStart.lowerBound..<src.endIndex])

        XCTAssertTrue(rowBody.contains("doc.on.doc"),
                      "EntryRow must keep the copy button (doc.on.doc icon)")
        XCTAssertTrue(rowBody.contains("trash"),
                      "EntryRow must include a Delete button (trash icon) per row")
    }

    func testDeleteButtonActionCallsStorageDelete() throws {
        let src = try String(contentsOfFile: "/Users/mac/work/github/clipboard-history-mac/Sources/ClipboardHistoryMac/MainWindowView.swift", encoding: .utf8)
        let entryRowRange = src.range(of: "struct EntryRow")!
        let rowBody = src[entryRowRange.lowerBound..<src.endIndex]
        XCTAssertTrue(rowBody.contains("storage.delete(entry)"),
                      "EntryRow's Delete button must invoke storage.delete(entry)")
        XCTAssertFalse(rowBody.contains("role: .destructive"),
                       "Per-row delete is non-destructive-styled to avoid SwiftUI confirmation prompts")
    }
}
