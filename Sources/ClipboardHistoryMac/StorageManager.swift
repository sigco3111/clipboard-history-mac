import SwiftUI
import AppKit
import CryptoKit

/// 로컬 파일 시스템 저장 (~/Library/Application Support/ClipboardHistoryMac/)
@MainActor
final class StorageManager: ObservableObject {
    struct Entry: Codable, Identifiable {
        var id: Int64
        var type: String  // "text" | "image"
        var text: String?
        var imageFilename: String?
        var mime: String?
        var ts: Date
        var hash: String
        var size: Int
    }

    @Published private(set) var entries: [Entry] = []
    @Published var searchQuery: String = ""
    @Published var imageLimit: Int = 100 {
        didSet { UserDefaults.standard.set(imageLimit, forKey: "imageLimit") }
    }

    private let baseDir: URL
    private let entriesFile: URL
    private let imagesDir: URL
    private let metadataFile: URL

    init() {
        // ~/Library/Application Support/ClipboardHistoryMac/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("ClipboardHistoryMac", isDirectory: true)
        entriesFile = baseDir.appendingPathComponent("entries.json")
        imagesDir = baseDir.appendingPathComponent("images", isDirectory: true)
        metadataFile = baseDir.appendingPathComponent("metadata.json")

        // 디렉토리 생성
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // 이미지 한도 로드
        let saved = UserDefaults.standard.integer(forKey: "imageLimit")
        imageLimit = saved > 0 ? saved : 100

        load()
    }

    // MARK: - Load / Save

    private func load() {
        guard let data = try? Data(contentsOf: entriesFile),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.ts > $1.ts }
    }

    private func save() {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        try? data.write(to: entriesFile, options: .atomic)
    }

    // MARK: - Public API

    var filteredEntries: [Entry] {
        guard !searchQuery.isEmpty else { return entries }
        let q = searchQuery.lowercased()
        return entries.filter { entry in
            if let text = entry.text {
                return text.lowercased().contains(q)
            }
            if let filename = entry.imageFilename {
                return filename.lowercased().contains(q)
            }
            return false
        }
    }

    /// 텍스트 중복 체크
    func hasText(hash: String) -> Bool {
        return entries.contains { $0.hash == hash && $0.type == "text" }
    }

    /// 이미지 중복 체크
    func hasImage(hash: String) -> Bool {
        return entries.contains { $0.hash == hash && $0.type == "image" }
    }

    /// 텍스트 추가
    @discardableResult
    func addText(_ text: String) -> Int64 {
        let hash = sha256(Data(text.utf8))
        let id = (entries.first?.id ?? 0) + 1
        let entry = Entry(
            id: id, type: "text",
            text: text, imageFilename: nil, mime: nil,
            ts: Date(), hash: hash, size: text.utf8.count
        )
        entries.insert(entry, at: 0)
        save()
        return id
    }

    /// 이미지 추가
    @discardableResult
    func addImage(data: Data, mime: String) -> Int64 {
        let hash = sha256(data)
        let ext = mimeToExt(mime)
        let filename = "\(hash).\(ext)"
        let filepath = imagesDir.appendingPathComponent(filename)

        // 디스크에 저장
        try? data.write(to: filepath, options: .atomic)

        let id = (entries.first?.id ?? 0) + 1
        let entry = Entry(
            id: id, type: "image",
            text: nil, imageFilename: filename, mime: mime,
            ts: Date(), hash: hash, size: data.count
        )
        entries.insert(entry, at: 0)

        // 이미지 한도 초과 시 오래된 것부터 삭제
        enforceImageLimit()

        save()
        return id
    }

    /// 이미지 한도 적용 (오래된 것부터 삭제)
    private func enforceImageLimit() {
        let imageEntries = entries.enumerated().filter { $0.element.type == "image" }
        guard imageEntries.count > imageLimit else { return }

        // 오래된 것 찾기 (오름차순 정렬)
        let sorted = imageEntries.sorted { $0.element.ts < $1.element.ts }
        let toDelete = sorted.prefix(imageEntries.count - imageLimit)

        for (_, entry) in toDelete {
            // 디스크에서도 삭제
            if let filename = entry.imageFilename {
                let filepath = imagesDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: filepath)
            }
            // entries에서도 삭제
            entries.removeAll { $0.id == entry.id }
        }
    }

    /// 항목 삭제
    func delete(_ entry: Entry) {
        if entry.type == "image", let filename = entry.imageFilename {
            let filepath = imagesDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: filepath)
        }
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// 전체 삭제
    func clearAll() {
        // 디스크 이미지 정리
        for entry in entries where entry.type == "image" {
            if let filename = entry.imageFilename {
                let filepath = imagesDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: filepath)
            }
        }
        entries.removeAll()
        save()
    }

    /// 클립보드에 복사 (텍스트)
    func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// 클립보드에 복사 (이미지)
    func copyImage(filename: String) {
        let filepath = imagesDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: filepath),
              let nsImage = NSImage(data: data) else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    /// 이미지 파일 URL (Finder에서 열기용)
    func imageURL(filename: String) -> URL {
        return imagesDir.appendingPathComponent(filename)
    }

    // MARK: - Helpers

    private func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func mimeToExt(_ mime: String) -> String {
        switch mime {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        case "image/bmp": return "bmp"
        default: return "bin"
        }
    }
}