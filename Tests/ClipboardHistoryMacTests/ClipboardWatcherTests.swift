import Foundation
import AppKit
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class ClipboardWatcherTests: XCTestCase {

    func testImageFromPasteboardIsSavedWhenNotDuplicated() {
        let storage = TestStorageFactory.makeStorage(suffix: "watcher-image")
        let watcher = ClipboardWatcher(storage: storage)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-\(UUID().uuidString)"))
        guard let pngData = makeSolidColorPNG(width: 4, height: 4),
              let nsImage = NSImage(data: pngData),
              let tiff = nsImage.tiffRepresentation else {
            XCTFail("fixture build failed")
            return
        }
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)

        watcher.processNow(pasteboard: pasteboard)

        XCTAssertEqual(storage.entries.count, 1,
                       "watcher must save exactly one image; got \(storage.entries.count)")
        let entry = storage.entries.first
        XCTAssertEqual(entry?.type, "image")
        XCTAssertNotNil(entry?.imageFilename)
        XCTAssertFalse(entry?.hash.isEmpty ?? true)
    }

    func testDuplicateImageIsNotSavedTwice() {
        let storage = TestStorageFactory.makeStorage(suffix: "watcher-image-dup")
        let watcher = ClipboardWatcher(storage: storage)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-dup-\(UUID().uuidString)"))

        guard let pngData = makeSolidColorPNG(width: 2, height: 2),
              let nsImage = NSImage(data: pngData),
              let tiff = nsImage.tiffRepresentation else {
            XCTFail("fixture build failed")
            return
        }
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)
        watcher.processNow(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)
        watcher.processNow(pasteboard: pasteboard)

        XCTAssertEqual(storage.entries.count, 1,
                       "duplicate pasteboard image must collapse into a single entry")
    }

    func testWatcherCapturesImmediatelyAfterInit() {
        NSPasteboard.general.clearContents()
        let settleExp = expectation(description: "pasteboard settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { settleExp.fulfill() }
        wait(for: [settleExp], timeout: 1.0)

        let uniquePayload = "auto-init-\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uniquePayload, forType: .string)

        let storage = TestStorageFactory.makeStorage(suffix: "auto-init")
        let watcher = ClipboardWatcher(storage: storage)

        let captureExp = expectation(description: "capture processed")
        DispatchQueue.main.async {
            let captured = storage.entries.contains { $0.text == uniquePayload }
            XCTAssertTrue(captured,
                          "init() must process the pasteboard without external start()")
            captureExp.fulfill()
        }
        wait(for: [captureExp], timeout: 2.0)

        NSPasteboard.general.clearContents()
        _ = watcher
    }

    private func makeSolidColorPNG(width: Int, height: Int) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        bitmap.setColor(NSColor.systemRed, atX: 0, y: 0)
        return bitmap.representation(using: .png, properties: [:])
    }
}
