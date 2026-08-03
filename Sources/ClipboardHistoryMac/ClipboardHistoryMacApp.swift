import SwiftUI
import AppKit

@main
struct ClipboardHistoryMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var storage = StorageManager()
    @StateObject private var watcher: ClipboardWatcher

    init() {
        let storage = StorageManager()
        let watcher = ClipboardWatcher(storage: storage)
        _storage = StateObject(wrappedValue: storage)
        _watcher = StateObject(wrappedValue: watcher)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                storage: storage,
                watcher: watcher,
                openFullHistory: { [weak appDelegate] in
                    appDelegate?.openMainWindow(storage: storage, watcher: watcher)
                }
            )
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                if watcher.capturedCount > 0 {
                    Text("\(watcher.capturedCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Clipboard History", id: "main") {
            MainWindowView(
                storage: storage,
                watcher: watcher
            )
            .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 600)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func openMainWindow(storage: StorageManager, watcher: ClipboardWatcher) {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = mainWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        if let existing = mainWindowController?.window {
            existing.makeKeyAndOrderFront(nil)
            mainWindowController = nil
            return
        }

        let controller = NSHostingController(
            rootView: MainWindowView(storage: storage, watcher: watcher)
                .frame(minWidth: 700, minHeight: 500)
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "Clipboard History"
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.center()
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        mainWindowController = windowController
    }
}
