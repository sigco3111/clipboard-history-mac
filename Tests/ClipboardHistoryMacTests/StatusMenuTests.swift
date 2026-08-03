import Foundation
import AppKit
import SwiftUI
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class StatusMenuTests: XCTestCase {

    func testAppBodyDoesNotUseSwiftUIMenuBarExtra() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertFalse(src.contains("MenuBarExtra"),
                       "App body must NOT use SwiftUI MenuBarExtra (unreliable click wire on LSUIElement)")
        XCTAssertFalse(src.contains("openWindow"),
                       "App body must not use SwiftUI openWindow environment for the menu")
        XCTAssertFalse(src.contains("Window(\"Clipboard History\""),
                       "App body must not declare a SwiftUI Window scene named 'Clipboard History'")
        XCTAssertTrue(src.contains("NSStatusBar.system"),
                      "App body must use NSStatusBar.system.statusItem + NSMenu for the menu")
    }

    func testOpenMainHistoryMenuItemIsRegistered() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("\"전체 히스토리 열기\""),
                      "AppDelegate must register an NSMenuItem titled '전체 히스토리 열기'")
        XCTAssertTrue(src.contains("#selector(openMainWindow"),
                      "The 'open full history' item must be wired to AppDelegate.openMainWindow(_:)")
    }

    func testAppDelegateOpenMainWindowCreatesNSWindow() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("func openMainWindow(_ sender: Any?)"),
                      "AppDelegate must expose openMainWindow(_:) as the menu action")
        XCTAssertTrue(src.contains("window.title = \"Clipboard History\""),
                      "openMainWindow must set the window title to 'Clipboard History'")
        XCTAssertTrue(src.contains("NSHostingController"),
                      "openMainWindow must host MainWindowView via NSHostingController")
        XCTAssertTrue(src.contains("NSWindowController"),
                      "openMainWindow must use NSWindowController to present the window")
        XCTAssertTrue(src.contains("window.makeKeyAndOrderFront"),
                      "openMainWindow must call makeKeyAndOrderFront to surface the window")
    }

    func testCaptureButtonRemovalStillHolds() throws {
        let menu = try sourceText(of: "ClipboardHistoryMacApp.swift")
        let win = try sourceText(of: "MainWindowView.swift")
        XCTAssertFalse(menu.contains("지금 캡처"),
                       "the Capture Now label must not appear in the AppDelegate-driven menu")
        XCTAssertFalse(win.contains("지금 캡처"),
                       "the Capture Now label must not appear in the main window")
        XCTAssertFalse(menu.contains("captureNow"),
                       "no captureNow references in AppDelegate")
    }

    func testMenuContentViewSourceNoLongerReferencedFromAppBody() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertFalse(src.contains("MenuContentView"),
                       "MenuContentView should be retired — App uses NSMenu directly")
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
