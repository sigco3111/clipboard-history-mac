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

@MainActor
final class StatusMenuContentTests: XCTestCase {

    /// The menu must include machine-consumed tokens: a status header, recent-text
    /// section, and the open-full-history target/action wire. These are the surface
    /// elements the user sees and that the closure injection path depends on.
    func testAppDelegateSourceContainsExpectedMenuElements() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("NSMenu()"),
                      "AppDelegate must build an NSMenu programmatically")
        XCTAssertTrue(src.contains("전체 히스토리 열기"),
                      "Menu must include '전체 히스토리 열기' item")
        XCTAssertTrue(src.contains("#selector(openMainWindow"),
                      "Menu's open-full-history item must target #selector(openMainWindow(_:))")
        XCTAssertTrue(src.contains("statusHeaderItem"),
                      "AppDelegate must maintain a status header item")
        XCTAssertTrue(src.contains("recentTextItems"),
                      "AppDelegate must maintain recent-text menu slots")
        XCTAssertTrue(src.contains("permissionWarningItem"),
                      "AppDelegate must surface permission state in the menu")
    }

    /// The watcher must publish `lastIssue` so the menu can show '권한 필요' when reads
    /// silently fail (the macOS 14+ TCC-denial signature).
    func testWatcherExposesPermissionState() throws {
        let src = try sourceText(of: "ClipboardWatcher.swift")
        XCTAssertTrue(src.contains("@Published var lastIssue"),
                      "ClipboardWatcher must publish a lastIssue field for UI")
        XCTAssertTrue(src.contains("consecutiveNilReads"),
                      "ClipboardWatcher must track consecutive unreadable changes")
        XCTAssertTrue(src.contains("permissionLikelyDenied"),
                      "ClipboardWatcher must include the permissionLikelyDenied case")
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
@MainActor
final class ActivationPolicyTests: XCTestCase {

    /// Regression-lock: AppDelegate.openMainWindow must switch NSApp activation policy
    /// to .regular so the LSUIElement (= accessory) menu-bar app can show its main
    /// window on macOS 14+ where accessory apps silently swallow makeKeyAndOrderFront.
    func testAppDelegateSourceIncludesActivationPolicyRegularSwitch() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("NSApp.setActivationPolicy(.regular)"),
                      "AppDelegate.openMainWindow must call NSApp.setActivationPolicy(.regular) before showing the window")
        XCTAssertTrue(src.contains("NSApp.setActivationPolicy(.accessory)"),
                      "AppDelegate.openMainWindow must restore .accessory when the window closes (willCloseNotification)")
        XCTAssertTrue(src.contains("window.makeKeyAndOrderFront"),
                      "Window presentation path must include makeKeyAndOrderFront")
        XCTAssertTrue(src.contains("orderFrontRegardless") || src.contains("makeKeyAndOrderFront"),
                      "Window presentation path must include at least one make-key/order-front call")
    }

    private func sourceText(of file: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/ClipboardHistoryMac/\(file)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
@MainActor
final class RecentItemReCopyTests: XCTestCase {

    func testRecentTextItemActionReCopiesEntryToPasteboard() throws {
        let storage = TestStorageFactory.makeStorage(suffix: "recopy-text")
        let entry = StorageManager.Entry(
            id: 1, type: "text",
            text: "recent-text-value-for-recopy",
            imageFilename: nil, mime: nil,
            ts: Date(), hash: "ignored", size: 30
        )

        let host = ClickHost()
        host.storage = storage
        NSPasteboard.general.clearContents()

        let selector = #selector(host.recentTextClicked(_:))
        let item = NSMenuItem(
            title: "복사",
            action: selector,
            keyEquivalent: ""
        )
        item.target = host
        item.representedObject = entry

        _ = host.perform(selector, with: item)

        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string), entry.text,
            "clicking recent-text item must put that entry's text on the pasteboard"
        )
    }

    func testRecentImageItemActionReCopiesImageToPasteboard() throws {
        let storage = TestStorageFactory.makeStorage(suffix: "recopy-image")
        let payload = Data(bytes: [
            0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
            0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
            0x0c, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x60, 0x60, 0x60, 0x00,
            0x00, 0x00, 0x04, 0x00, 0x01, 0xf6, 0x17, 0x38, 0x55, 0x00, 0x00, 0x00,
            0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
        ], count: 69)
    }

    /// Source-text regression: AppDelegate's recent items must wire target/action
    /// instead of leaving items permanently disabled.
    func testAppDelegateWiresRecentItemsWithTargetAndAction() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(
            src.contains("representedObject") || src.contains("tag"),
            "Recent items must carry per-item state (representedObject or tag)"
        )
        XCTAssertTrue(
            src.contains("recentTextClicked") || src.contains("recentTextMenuItemClicked"),
            "Recent text item must invoke a re-copy selector"
        )
        XCTAssertTrue(
            src.contains("recentImageClicked") || src.contains("recentImageMenuItemClicked"),
            "Recent image item must invoke a re-copy selector"
        )
    }

    private func sourceText(of file: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/ClipboardHistoryMac/\(file)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
private final class ClickHost: NSObject {
    var storage: StorageManager?

    @objc func recentTextClicked(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? StorageManager.Entry else { return }
        if let text = entry.text {
            storage?.copyText(text)
        }
    }

    @objc func recentImageClicked(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? StorageManager.Entry else { return }
        if let filename = entry.imageFilename {
            storage?.copyImage(filename: filename)
        }
    }
}
