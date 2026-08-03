import SwiftUI
import AppKit
import Combine
import CryptoKit

/// NSPasteboard 폴링 + 변경 감지 + 자동 저장
@MainActor
final class ClipboardWatcher: ObservableObject {
    @Published var capturedCount: Int = 0
    @Published var lastCaptureTime: Date?
    @Published var isPaused: Bool = false
    /// Captures the most recent permission/failure state observed by tick(). UI surfaces
    /// this to the user.
    @Published var lastIssue: WatcherIssue?

    enum WatcherIssue: Equatable {
        case noChangeYet
        case permissionLikelyDenied
    }

    private let storage: StorageManager
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastTextHash: String = ""
    private var lastImageHash: String = ""
    private var consecutiveNilReads: Int = 0

    init(storage: StorageManager) {
        self.storage = storage
        self.capturedCount = storage.entries.count
        self.lastChangeCount = NSPasteboard.general.changeCount
        start()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            lastChangeCount = NSPasteboard.general.changeCount
        } else {
            isPaused = true
        }
    }

    func processNow(pasteboard: NSPasteboard) {
        tick(pasteboard: pasteboard)
    }

    /// 폴링 tick
    private let pollInterval: TimeInterval = 1.0

    private func tick(pasteboard: NSPasteboard = .general) {
        guard !isPaused else { return }

        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 1) 이미지
        if let imageData = captureImage(pasteboard: pasteboard) {
            consecutiveNilReads = 0
            let hash = sha256(imageData)
            if hash != lastImageHash {
                if !storage.hasImage(hash: hash) {
                    _ = storage.addImage(data: imageData, mime: detectMime(data: imageData))
                    capturedCount = storage.entries.count
                    lastCaptureTime = Date()
                }
                lastImageHash = hash
            }
            lastIssue = nil
            return
        }

        // 2) 텍스트
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            consecutiveNilReads = 0
            let hash = sha256(Data(text.utf8))
            if hash != lastTextHash {
                if !storage.hasText(hash: hash) {
                    _ = storage.addText(text)
                    capturedCount = storage.entries.count
                    lastCaptureTime = Date()
                }
                lastTextHash = hash
            }
            lastIssue = nil
            return
        }

        // changeCount changed but no readable content — likely TCC denial on macOS 14+.
        consecutiveNilReads += 1
        if consecutiveNilReads >= 3 {
            lastIssue = .permissionLikelyDenied
        }
    }

    private func captureImage(pasteboard: NSPasteboard) -> Data? {
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        if let tiffData = pasteboard.data(forType: .tiff),
           let png = tiffToPNG(tiffData) {
            return png
        }
        if let anyImageData = pasteboard.data(forType: .init("public.image")),
           let png = imageDataToPNG(anyImageData) {
            return png
        }
        return nil
    }

    private func tiffToPNG(_ tiff: Data) -> Data? {
        if let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            return png
        }
        if let png = imageDataToPNG(tiff) {
            return png
        }
        return nil
    }

    private func imageDataToPNG(_ data: Data) -> Data? {
        if let bitmap = NSBitmapImageRep(data: data) {
            return bitmap.representation(using: .png, properties: [:])
        }
        return nil
    }

    private func detectMime(data: Data) -> String {
        if data.count >= 8 {
            let sig = [UInt8](data.prefix(8))
            if sig[0] == 0x89 && sig[1] == 0x50 && sig[2] == 0x4E && sig[3] == 0x47 {
                return "image/png"
            }
            if sig[0] == 0xFF && sig[1] == 0xD8 && sig[2] == 0xFF {
                return "image/jpeg"
            }
            if data.count >= 12 {
                let riff = String(data: data.prefix(4), encoding: .ascii) ?? ""
                let webp = String(data: data.subdata(in: 8..<12), encoding: .ascii) ?? ""
                if riff == "RIFF" && webp == "WEBP" {
                    return "image/webp"
                }
            }
        }
        return "image/png"
    }

    private func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
