import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var storage: StorageManager?
    private var watcher: ClipboardWatcher?
    private var mainWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let storage = StorageManager()
        let watcher = ClipboardWatcher(storage: storage)
        self.storage = storage
        self.watcher = watcher

        installStatusMenu()
    }

    private func installStatusMenu() {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "전체 히스토리 열기",
            action: #selector(openMainWindow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let toggleItem = NSMenuItem(
            title: "자동 캡처 일시정지",
            action: #selector(togglePause(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let githubItem = NSMenuItem(
            title: "GitHub (단일 HTML 버전)",
            action: #selector(openGitHub(_:)),
            keyEquivalent: ""
        )
        githubItem.target = self
        menu.addItem(githubItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu

        let item = NSStatusBar.system.statusItem(withLength: CGFloat(-1))
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "ClipboardHistoryMac"
        )
        item.button?.imagePosition = NSControl.ImagePosition.imageLeft
        item.menu = menu
        self.statusItem = item
    }

    @objc func openMainWindow(_ sender: Any?) {
        guard let storage, let watcher else { return }
        NSApp.activate(ignoringOtherApps: true)
        if let existing = mainWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        if mainWindowController?.window != nil {
            mainWindowController?.window?.makeKeyAndOrderFront(nil)
            mainWindowController = nil
            return
        }

        let host = NSHostingController(
            rootView: MainWindowView(storage: storage, watcher: watcher)
                .frame(minWidth: 700, minHeight: 500)
        )
        let window = NSWindow(contentViewController: host)
        window.title = "Clipboard History"
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.center()
        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        mainWindowController = wc
    }

    @objc func togglePause(_ sender: Any?) {
        watcher?.togglePause()
        if let item = menu?.items.first(where: { $0.action == #selector(togglePause(_:)) }) {
            item.title = (watcher?.isPaused ?? false) ? "자동 캡처 재개" : "자동 캡처 일시정지"
        }
    }

    @objc func openGitHub(_ sender: Any?) {
        if let url = URL(string: "https://github.com/sigco3111/clipboard-history") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

@main
struct ClipboardHistoryMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
