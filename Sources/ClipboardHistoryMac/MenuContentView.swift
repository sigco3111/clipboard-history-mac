import SwiftUI
import AppKit

struct MenuContentView: View {
    @ObservedObject var storage: StorageManager
    @ObservedObject var watcher: ClipboardWatcher
    /// Injected by the App; SwiftUI's @Environment(\.openWindow) does not reach Window scenes
    /// reliably when this view is hosted inside MenuBarExtra(.window).
    var openFullHistory: () -> Void
    @Environment(\.openURL) private var openURL

    init(storage: StorageManager,
         watcher: ClipboardWatcher,
         openFullHistory: @escaping () -> Void) {
        self.storage = storage
        self.watcher = watcher
        self.openFullHistory = openFullHistory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                Text("Clipboard History")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if watcher.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            let textCount = storage.entries.filter { $0.type == "text" }.count
            let imageCount = storage.entries.filter { $0.type == "image" }.count
            HStack(spacing: 12) {
                Label("\(textCount)", systemImage: "text.alignleft")
                Label("\(imageCount)", systemImage: "photo")
                Spacer()
                if let last = watcher.lastCaptureTime {
                    Text(last, style: .relative)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            let recentText = storage.entries.filter { $0.type == "text" }.prefix(3)
            if !recentText.isEmpty {
                Text("최근 텍스트")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                ForEach(Array(recentText)) { entry in
                    Button {
                        if let text = entry.text {
                            storage.copyText(text)
                        }
                    } label: {
                        Text(entry.text?.prefix(40).appending("...") ?? "")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    openFullHistory()
                } label: {
                    Label("전체 히스토리 열기", systemImage: "rectangle.stack")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Button {
                    watcher.togglePause()
                } label: {
                    if watcher.isPaused {
                        Label("자동 캡처 재개", systemImage: "play.circle")
                    } else {
                        Label("자동 캡처 일시정지", systemImage: "pause.circle")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .padding(.vertical, 4)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    if let url = URL(string: "https://github.com/sigco3111/clipboard-history") {
                        openURL(url)
                    }
                } label: {
                    Label("GitHub (단일 HTML 버전)", systemImage: "link")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("종료", systemImage: "power")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }
}
