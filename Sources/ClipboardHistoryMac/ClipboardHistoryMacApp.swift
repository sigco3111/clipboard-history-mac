import SwiftUI
import AppKit

@main
struct ClipboardHistoryMacApp: App {
    @StateObject private var storage = StorageManager()
    @StateObject private var watcher: ClipboardWatcher

    init() {
        // Storage와 Watcher는 서로 의존 → 수동 초기화
        let storage = StorageManager()
        let watcher = ClipboardWatcher(storage: storage)
        _storage = StateObject(wrappedValue: storage)
        _watcher = StateObject(wrappedValue: watcher)
    }

    var body: some Scene {
        // 1) MenuBarExtra — 메뉴바 상주 아이콘
        MenuBarExtra {
            MenuContentView(
                storage: storage,
                watcher: watcher
            )
        } label: {
            // 메뉴바 아이콘 + 카운트
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                if watcher.capturedCount > 0 {
                    Text("\(watcher.capturedCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .menuBarExtraStyle(.window)

        // 2) 메인 윈도우 (검색 + 목록)
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