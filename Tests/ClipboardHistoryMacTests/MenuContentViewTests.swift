import Foundation
import AppKit
import SwiftUI
import XCTest
@testable import ClipboardHistoryMac

@MainActor
final class MenuContentViewTests: XCTestCase {

    func testOpenFullHistoryUsesInjectedClosure() {
        let storage = TestStorageFactory.makeStorage(suffix: "menu-open")
        let watcher = ClipboardWatcher(storage: storage)
        var calledCount = 0
        let view = MenuContentView(
            storage: storage,
            watcher: watcher,
            openFullHistory: { calledCount += 1 }
        )
        view.openFullHistory()
        view.openFullHistory()
        XCTAssertEqual(calledCount, 2,
                       "MenuContentView.openFullHistory() must invoke the injected closure")
    }

    func testMenuContentViewHasNoDeadShowMainWindowBinding() throws {
        let src = try sourceText(of: "MenuContentView.swift")
        XCTAssertFalse(src.contains("showMainWindow = true"),
                       "MenuContentView must not mutate the dead showMainWindow binding")
        XCTAssertFalse(src.contains("@Binding var showMainWindow"),
                       "MenuContentView must not declare a @Binding showMainWindow")
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

    func testInjectedOpenFullHistoryClosureSurfacesAWindow() throws {
        let storage = TestStorageFactory.makeStorage(suffix: "menu-surface")
        let watcher = ClipboardWatcher(storage: storage)

        var presentedController: NSWindowController?
        var didPresent = false
        let view = MenuContentView(
            storage: storage,
            watcher: watcher,
            openFullHistory: {
                guard !didPresent else { return }
                didPresent = true
                let host = NSHostingController(
                    rootView: MainWindowView(storage: storage, watcher: watcher)
                        .frame(minWidth: 700, minHeight: 500)
                )
                let window = NSWindow(contentViewController: host)
                window.title = "Clipboard History"
                window.setContentSize(NSSize(width: 900, height: 600))
                let controller = NSWindowController(window: window)
                controller.showWindow(nil)
                presentedController = controller
            }
        )

        view.openFullHistory()

        let exp = expectation(description: "window appears")
        DispatchQueue.main.async {
            let titles = NSApp.windows.map(\.title)
            XCTAssertTrue(titles.contains("Clipboard History"),
                          "the openFullHistory closure must surface an NSWindow titled 'Clipboard History'; got \(titles)")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        presentedController?.close()
    }

    func testAppWiringPassesRealOpenFullHistoryClosure() throws {
        let src = try sourceText(of: "ClipboardHistoryMacApp.swift")
        XCTAssertTrue(src.contains("openFullHistory:"),
                      "App body must pass an openFullHistory closure into MenuContentView")
        XCTAssertTrue(src.contains("appDelegate"),
                      "App body must wire openFullHistory through AppDelegate")
        XCTAssertFalse(src.contains("openWindow(id: \"main\")"),
                       "App body must not rely on SwiftUI openWindow for the menu (unreliable in MenuBarExtra popup)")
        XCTAssertTrue(src.contains("func openMainWindow("),
                      "AppDelegate must expose openMainWindow method")
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
