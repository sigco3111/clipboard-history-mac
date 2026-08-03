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

    private let storage: StorageManager
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastTextHash: String = ""
    private var lastImageHash: String = ""

    /// 폴링 간격 (초)
    private let pollInterval: TimeInterval = 1.0

    init(storage: StorageManager) {
        self.storage = storage
        self.capturedCount = storage.entries.count
        self.lastChangeCount = NSPasteboard.general.changeCount
        start()
    }

    /// 자동 캡처 시작
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // 즉시 1회 실행 (대기 시간 제거)
        tick()
    }

    /// 자동 캡처 중지
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 일시 정지 / 재개
    func togglePause() {
        if isPaused {
            isPaused = false
            lastChangeCount = NSPasteboard.general.changeCount
        } else {
            isPaused = true
        }
    }

    /// Tests / manual triggers: process the supplied pasteboard synchronously.
    func processNow(pasteboard: NSPasteboard) {
        tick(pasteboard: pasteboard)
    }

    /// 폴링 tick
    private func tick(pasteboard: NSPasteboard = .general) {
        guard !isPaused else { return }

        let currentChangeCount = pasteboard.changeCount

        // 변경 없으면 skip
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 1) 이미지 먼저 시도 (스크린샷)
        if let imageData = captureImage(pasteboard: pasteboard) {
            let hash = sha256(imageData)
            // 중복 체크
            if hash != lastImageHash {
                if !storage.hasImage(hash: hash) {
                    _ = storage.addImage(data: imageData, mime: detectMime(data: imageData))
                    capturedCount = storage.entries.count
                    lastCaptureTime = Date()
                }
                lastImageHash = hash
            }
            return
        }

        // 2) 텍스트
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let hash = sha256(Data(text.utf8))
            if hash != lastTextHash {
                if !storage.hasText(hash: hash) {
                    _ = storage.addText(text)
                    capturedCount = storage.entries.count
                    lastCaptureTime = Date()
                }
                lastTextHash = hash
            }
        }
    }

    /// 이미지 캡처 (PNG/TIFF/비트맵 우선)
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

    /// MIME 타입 감지 (간단 버전)
    private func detectMime(data: Data) -> String {
        if data.count >= 8 {
            let sig = [UInt8](data.prefix(8))
            // PNG: 89 50 4E 47 0D 0A 1A 0A
            if sig[0] == 0x89 && sig[1] == 0x50 && sig[2] == 0x4E && sig[3] == 0x47 {
                return "image/png"
            }
            // JPEG: FF D8 FF
            if sig[0] == 0xFF && sig[1] == 0xD8 && sig[2] == 0xFF {
                return "image/jpeg"
            }
            // WebP: RIFF....WEBP
            if data.count >= 12 {
                let riff = String(data: data.prefix(4), encoding: .ascii) ?? ""
                let webp = String(data: data.subdata(in: 8..<12), encoding: .ascii) ?? ""
                if riff == "RIFF" && webp == "WEBP" {
                    return "image/webp"
                }
            }
        }
        return "image/png" // 기본값
    }

    /// SHA-256 해시 (16진수)
    private func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}