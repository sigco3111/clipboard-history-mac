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
