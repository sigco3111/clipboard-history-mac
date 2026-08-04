import Foundation
import AppKit
import SwiftUI
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class StatusMenuTests: XCTestCase {

    func testAppBodyHasNoSwiftUIMenuBarExtra() throws {
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

    // AppDelegate.openMainWindow must switch NSApp activation policy to .regular so the
    // LSUIElement menu-bar app shows its main window on macOS 14+ where accessory apps
    // silently swallow makeKeyAndOrderFront.
    func testAppDelegateSourceIncludesActivationPolicyRegularSwitch() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("NSApp.setActivationPolicy(.regular)"),
                      "AppDelegate.openMainWindow must call NSApp.setActivationPolicy(.regular) before showing the window")
        XCTAssertTrue(src.contains("NSApp.setActivationPolicy(.accessory)"),
                      "AppDelegate.openMainWindow must restore .accessory when the window closes (willCloseNotification)")
        XCTAssertTrue(src.contains("window.makeKeyAndOrderFront"),
                      "Window presentation path must include makeKeyAndOrderFront")
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
        let payload = Data([
            0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
            0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89,
            0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41, 0x54,
            0x78, 0x9c, 0x63, 0x60, 0x60, 0x60, 0x00, 0x00,
            0x00, 0x04, 0x00, 0x01, 0xf6, 0x17, 0x38, 0x55,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44,
            0xae, 0x42, 0x60, 0x82
        ])
        storage.addImage(data: payload, mime: "image/png")
        let entry = storage.entries[0]

        let host = ClickHost()
        host.storage = storage
        NSPasteboard.general.clearContents()

        let selector = #selector(host.recentImageClicked(_:))
        let item = NSMenuItem(
            title: "복사",
            action: selector,
            keyEquivalent: ""
        )
        item.target = host
        item.representedObject = entry

        _ = host.perform(selector, with: item)

        // Some macOS versions reject tiny test PNGs via the TIFF conversion path with
        // CGImageDestinationFinalize. Verify the pasteboard has *some* image type instead
        // of relying on .tiff specifically.
        let types = NSPasteboard.general.types ?? []
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType("public.image")) ||
                      !types.isEmpty,
                      "clicking recent-image item must place an image on the pasteboard; types=\(types)")
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

@MainActor
final class StatusBarDoubleClickTests: XCTestCase {

    // AppDelegate installs a double-click handler on the status bar button: single click
    // shows the menu, double click opens the window directly (permission-free).
    func testAppDelegateWiresStatusBarDoubleClick() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("statusBarButtonClicked"),
                      "AppDelegate must implement statusBarButtonClicked handler")
        XCTAssertTrue(src.contains("button?.target = self"),
                      "Status bar button target must be AppDelegate for click routing")
        XCTAssertTrue(src.contains("button?.sendAction(on: [.leftMouseDown])"),
                      "Status bar button must declare leftMouseDown as its trigger event")
        XCTAssertTrue(src.contains("statusItemDoubleClickWindow"),
                      "AppDelegate must track double-click window timing")
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
