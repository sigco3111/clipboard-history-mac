import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var storage: StorageManager?
    private var watcher: ClipboardWatcher?
    private var mainWindowController: NSWindowController?
    private var statusHeaderItem: NSMenuItem?
    private var permissionWarningItem: NSMenuItem?
    private var refreshItem: NSMenuItem?
    private var recentTextHeader: NSMenuItem?
    private var recentImageHeader: NSMenuItem?
    private var recentTextItems: [NSMenuItem] = []
    private var recentImageItems: [NSMenuItem] = []
    private var watcherObservation: AnyCancellable?
    private var storageObservation: AnyCancellable?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let storage = StorageManager()
        let watcher = ClipboardWatcher(storage: storage)
        self.storage = storage
        self.watcher = watcher
        installStatusMenu()
        observeStateChanges()
    }

    private func observeStateChanges() {
        guard let watcher, let storage else { return }
        watcherObservation = watcher.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshMenu() }
        }
        storageObservation = storage.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshMenu() }
        }
    }

    private func installStatusMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem()
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        self.statusHeaderItem = headerItem

        let warningItem = NSMenuItem()
        warningItem.isEnabled = false
        warningItem.isHidden = true
        warningItem.title = ""
        menu.addItem(warningItem)
        self.permissionWarningItem = warningItem

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(
            title: "전체 히스토리 열기",
            action: #selector(openMainWindow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(
            title: "지금 새로 캡처",
            action: #selector(refreshCapture(_:)),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        self.refreshItem = refreshItem

        let toggleItem = NSMenuItem(
            title: watcher?.isPaused == true ? "자동 캡처 재개" : "자동 캡처 일시정지",
            action: #selector(togglePause(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.tag = 1
        menu.addItem(toggleItem)
        self.toggleItemRef = toggleItem

        menu.addItem(NSMenuItem.separator())

        let textHeader = NSMenuItem()
        textHeader.isEnabled = false
        textHeader.title = "최근 텍스트"
        menu.addItem(textHeader)
        self.recentTextHeader = textHeader

        for _ in 0..<3 {
            let item = NSMenuItem()
            item.isEnabled = false
            item.isHidden = true
            menu.addItem(item)
            self.recentTextItems.append(item)
        }

        menu.addItem(NSMenuItem.separator())

        let imageHeader = NSMenuItem()
        imageHeader.isEnabled = false
        imageHeader.title = "최근 이미지"
        menu.addItem(imageHeader)
        self.recentImageHeader = imageHeader

        for _ in 0..<3 {
            let item = NSMenuItem()
            item.isEnabled = false
            item.isHidden = true
            menu.addItem(item)
            self.recentImageItems.append(item)
        }

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

        refreshMenu()
    }

    private var toggleItemRef: NSMenuItem?

    private func refreshMenu() {
        guard let watcher, let storage else { return }
        let totalCount = storage.entries.count
        let textCount = storage.entries.filter { $0.type == "text" }.count
        let imageCount = storage.entries.filter { $0.type == "image" }.count

        // Status bar title with count
        if let button = statusItem?.button {
            let title = totalCount > 0 ? "  \(totalCount)" : nil
            button.title = title ?? ""
        }

        // Header item
        var lines: [String] = []
        lines.append("캡처: 총 \(totalCount)개 (텍스트 \(textCount) · 이미지 \(imageCount))")
        if let last = watcher.lastCaptureTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            lines.append("마지막: \(formatter.string(from: last))")
        } else {
            lines.append("대기 중")
        }
        statusHeaderItem?.title = lines.joined(separator: "\n")

        // Permission warning
        if watcher.lastIssue == .permissionLikelyDenied {
            permissionWarningItem?.title =
                "⚠️ 클립보드 권한 필요 — 시스템 설정 → 개인 정보 보호 → 클립보드에서 이 앱을 허용하세요"
            permissionWarningItem?.isHidden = false
        } else {
            permissionWarningItem?.isHidden = true
        }

        // Toggle item
        if watcher.isPaused {
            toggleItemRef?.title = "자동 캡처 재개"
        } else {
            toggleItemRef?.title = "자동 캡처 일시정지"
        }

        // Recent text items
        let textEntries = storage.entries.filter { $0.type == "text" }.prefix(3)
        for (idx, item) in recentTextItems.enumerated() {
            if idx < textEntries.count {
                let entry = textEntries[textEntries.count - 1 - idx]
                item.title = String((entry.text ?? "").prefix(60))
                item.isHidden = false
            } else {
                item.isHidden = true
            }
        }
        recentTextHeader?.title = textEntries.isEmpty ? "최근 텍스트 (없음)" : "최근 텍스트"

        // Recent image items — show count only (we don't surface image bytes in menu)
        let imageEntries = storage.entries.filter { $0.type == "image" }.prefix(3)
        for (idx, item) in recentImageItems.enumerated() {
            if idx < imageEntries.count {
                let entry = imageEntries[imageEntries.count - 1 - idx]
                let timestamp = entry.ts
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                let timeStr = formatter.string(from: timestamp)
                let sizeKB = Double(entry.size) / 1024.0
                item.title = "[\(timeStr)] \(String(format: "%.1f", sizeKB)) KB (\(entry.mime ?? "?"))"
                item.isHidden = false
            } else {
                item.isHidden = true
            }
        }
        recentImageHeader?.title = imageEntries.isEmpty ? "최근 이미지 (없음)" : "최근 이미지"
    }

    @objc func openMainWindow(_ sender: Any?) {
        guard let storage, let watcher else { return }
        FileHandle.standardError.write(Data("[ulw] openMainWindow entry\n".utf8))

        // Reuse the existing window if it has been asked to close (isVisible false) but
        // the controller still holds a strong reference.
        if let existing = mainWindowController?.window {
            if existing.isVisible {
                FileHandle.standardError.write(Data("[ulw] reusing visible window; bringing to front\n".utf8))
                bringWindowToFront(existing)
                return
            }
            FileHandle.standardError.write(Data("[ulw] dropping stale window controller\n".utf8))
            mainWindowController = nil
        }

        // LSUIElement (= accessory) apps on macOS 14+ silently swallow
        // `makeKeyAndOrderFront` unless we temporarily switch to `.regular`. The
        // standard recipe is documented in TN2083.
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy != .regular {
            FileHandle.standardError.write(Data("[ulw] switching activationPolicy accessory → regular\n".utf8))
            NSApp.setActivationPolicy(.regular)
        }

        let host = NSHostingController(
            rootView: MainWindowView(storage: storage, watcher: watcher)
                .frame(minWidth: 700, minHeight: 500)
        )
        let window = NSWindow(contentViewController: host)
        window.title = "Clipboard History"
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false

        // Center on the main NSScreen.visibleFrame; some multi-display setups
        // have an off-main origin that puts window.center() outside the user's view.
        let visible = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
        if visible != .zero {
            let originX = visible.midX - 450
            let originY = visible.midY - 300
            window.setFrameOrigin(NSPoint(x: originX, y: originY))
        } else {
            window.center()
        }

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)

        // Aggressive presentation sequence — works for both .regular and
        // accidentally-still-.accessory contexts.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        FileHandle.standardError.write(Data("[ulw] window state: isVisible=\(window.isVisible) isKey=\(window.isKeyWindow) frame=\(window.frame)\n".utf8))

        // macOS 14+ quirk: switching back to .accessory while the window is on
        // screen hides it. We stay in .regular while the window is up and revert
        // when the window closes.
        let previousWasRegular = previousPolicy == .regular
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if !previousWasRegular {
                FileHandle.standardError.write(Data("[ulw] window closing; reverting activationPolicy → accessory\n".utf8))
                NSApp.setActivationPolicy(.accessory)
            }
            // Drop the controller so a fresh window is built next time.
            self.mainWindowController = nil
        }

        mainWindowController = wc
    }

    private func bringWindowToFront(_ window: NSWindow) {
        // For LSUIElement, even .regular activation policy occasionally needs a
        // second activate() call after the window is already on screen.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if let frame = NSScreen.main?.visibleFrame, frame.width > 0 {
            let targetOrigin = NSPoint(
                x: frame.midX - window.frame.width / 2,
                y: frame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(targetOrigin)
        }
        window.orderFrontRegardless()
        FileHandle.standardError.write(Data("[ulw] window brought to front; isVisible=\(window.isVisible)\n".utf8))
    }

    @objc func refreshCapture(_ sender: Any?) {
        let pb = NSPasteboard(name: NSPasteboard.Name("ulw-fake-\(UUID().uuidString)"))
        watcher?.processNow(pasteboard: pb)
    }

    @objc func togglePause(_ sender: Any?) {
        watcher?.togglePause()
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
