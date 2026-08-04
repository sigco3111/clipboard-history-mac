import SwiftUI
import AppKit

/// 메인 윈도우 (전체 히스토리 + 검색 + 복원/삭제)
struct MainWindowView: View {
    @ObservedObject var storage: StorageManager
    @ObservedObject var watcher: ClipboardWatcher
    @State private var selectedEntryID: Int64?

    var body: some View {
        VStack(spacing: 0) {
            // ─── Toolbar ───
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("검색 (텍스트 또는 파일명)", text: $storage.searchQuery)
                    .textFieldStyle(.plain)
                Spacer()
                Button {
                    watcher.togglePause()
                } label: {
                    if watcher.isPaused {
                        Label("재개", systemImage: "play.circle")
                    } else {
                        Label("일시정지", systemImage: "pause.circle")
                    }
                }
                Button(role: .destructive) {
                    storage.clearAll()
                } label: {
                    Label("전체 삭제", systemImage: "trash")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // ─── Status Bar ───
            HStack(spacing: 16) {
                Text("\(storage.filteredEntries.count)개 표시")
                    .foregroundStyle(.secondary)
                Divider().frame(height: 12)
                let textCount = storage.entries.filter { $0.type == "text" }.count
                let imageCount = storage.entries.filter { $0.type == "image" }.count
                Label("\(textCount) 텍스트", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(imageCount) 이미지", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if watcher.isPaused {
                    Label("자동 캡처 일시정지", systemImage: "pause.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                } else {
                    Label("자동 캡처 활성", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))

            Divider()

            // ─── List ───
            if storage.filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(storage.searchQuery.isEmpty ? "아직 캡처된 항목이 없어요" : "검색 결과가 없어요")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedEntryID) {
                    ForEach(storage.filteredEntries) { entry in
                        EntryRow(entry: entry, storage: storage)
                            .tag(entry.id)
                            .contextMenu {
                                Button("복사") {
                                    handleCopy(entry)
                                }
                                Button("삭제", role: .destructive) {
                                    storage.delete(entry)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            // Watcher already runs from init; nothing to start here.
        }
        .onDisappear {
            // Watcher keeps running so the menu-bar app continues to capture.
        }
    }

    private func handleCopy(_ entry: StorageManager.Entry) {
        if entry.type == "text", let text = entry.text {
            storage.copyText(text)
        } else if entry.type == "image", let filename = entry.imageFilename {
            storage.copyImage(filename: filename)
        }
    }
}

/// 개별 항목 행
struct EntryRow: View {
    let entry: StorageManager.Entry
    @ObservedObject var storage: StorageManager

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            if entry.type == "image" {
                if let filename = entry.imageFilename {
                    let url = storage.imageURL(filename: filename)
                    if let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 45)
                            .background(Color.black.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, height: 45)
                    }
                }
            } else {
                Image(systemName: "text.alignleft")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 60, height: 45)
            }

            // 메타
            VStack(alignment: .leading, spacing: 2) {
                if entry.type == "text", let text = entry.text {
                    Text(text.prefix(100).appending(text.count > 100 ? "..." : ""))
                        .lineLimit(2)
                        .font(.system(size: 12))
                } else if let filename = entry.imageFilename {
                    Text(filename)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(entry.ts, style: .date)
                    Text(entry.ts, style: .time)
                    if let mime = entry.mime {
                        Text(mime)
                    }
                    Text("\(entry.size) B")
                }
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    if entry.type == "text", let text = entry.text {
                        storage.copyText(text)
                    } else if entry.type == "image", let filename = entry.imageFilename {
                        storage.copyImage(filename: filename)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("복사")

                Button {
                    storage.delete(entry)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("삭제")
            }
        }
        .padding(.vertical, 4)
    }
}
