import Foundation
import AppKit
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class MenuContentViewTests: XCTestCase {

    func testMenuContentViewHasNoDeadShowMainWindowBinding() throws {
        let src = try sourceText(of: "MenuContentView.swift")
        XCTAssertFalse(src.contains("showMainWindow = true"),
                       "MenuContentView must not mutate the dead showMainWindow binding")
        XCTAssertFalse(src.contains("@Binding var showMainWindow"),
                       "MenuContentView must not declare a @Binding showMainWindow")
    }

    func testMenuContentViewCallsOpenWindowAction() throws {
        let src = try sourceText(of: "MenuContentView.swift")
        XCTAssertTrue(src.contains("openWindow(id: \"main\""),
                        "MenuContentView must call openWindow(id: \"main\") on the open-full-history button")
    }

    func testSourceContainsNoCaptureNowLabel() throws {
        let src = try sourceText(of: "MenuContentView.swift")
        XCTAssertFalse(src.contains("지금 캡처"),
                       "the Capture Now label must be removed from menu")
        let src2 = try sourceText(of: "MainWindowView.swift")
        XCTAssertFalse(src2.contains("지금 캡처"),
                       "the Capture Now label must be removed from main window")
    }

    func testCaptureNowCallersAreNone() throws {
        var hits: [String] = []
        for rel in ["MenuContentView.swift", "MainWindowView.swift", "ClipboardHistoryMacApp.swift"] {
            let s = try sourceText(of: rel)
            let lines = s.split(separator: "\n").enumerated().filter { _, l in
                l.contains("captureNow") && !l.contains("func captureNow")
            }
            for (idx, l) in lines {
                hits.append("\(rel):\(idx + 1): \(l.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(hits.isEmpty,
                      "no view/App site should call captureNow(); remaining hits: \(hits)")
    }

    private func sourceText(of file: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let root = here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/ClipboardHistoryMac/\(file)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
