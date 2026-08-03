# 🗂️ Clipboard History macOS

> **macOS 메뉴바 상주형** 클립보드 히스토리 — SwiftUI MenuBarExtra + NSPasteboard 폴링 + 로컬 파일 저장

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS_13%2B-green)](https://developer.apple.com/macos)
[![Built with SwiftUI](https://img.shields.io/badge/built_with-SwiftUI-orange)](https://developer.apple.com/xcode/swiftui/)
[![Swift 5.9+](https://img.shields.io/badge/swift-5.9%2B-blue)](https://www.swift.org)

---

## 📌 이 프로젝트는?

기존 [clipboard-history](https://github.com/sigco3111/clipboard-history) (브라우저 단일 HTML)의 **네이티브 macOS 메뉴바 앱** 버전이에요.

### ✨ 차이점

| 항목 | 단일 HTML | macOS 앱 |
|------|----------|----------|
| **메뉴바 상주** | ❌ | ✅ 항상 상주 |
| **자동 시작 (로그인 시)** | ❌ | ✅ Login Item 등록 |
| **시스템 클립보드 직접 접근** | 브라우저 sandbox | `NSPasteboard` native |
| **저장소** | IndexedDB | `~/Library/Application Support/...` |
| **빌드** | 불필요 | macOS + Xcode/Swift |

## 🎯 작동 방식

```
[메뉴바] 📋 23
   ├─ 상태: 텍스트 15, 이미지 8
   ├─ 최근 5개 텍스트 미리보기 (클릭 시 클립보드 복사)
   ├─ [전체 히스토리 열기] → 메인 윈도우
   ├─ [지금 캡처] [자동 캡처 일시정지/재개]
   ├─ [GitHub] [종료]
```

- **1초마다** `NSPasteboard.general.changeCount` 폴링
- 변경 감지 시 → 텍스트/이미지 자동 캡처
- **SHA-256 해시**로 동일 항목 중복 방지
- **이미지 한도** (기본 100개, 10~500 조절) 초과 시 오래된 것부터 삭제

## 🚀 빌드 & 실행 (로컬)

### ⚙️ 요구사항
- **macOS 13.0+** (Ventura 이후 — `MenuBarExtra` API)
- **Xcode 15+** 또는 **Swift 5.9+** Command Line Tools
- **Apple Developer 계정 불필요** (본인 macOS 사용 시)

### 방법 A: Xcode (가장 쉬움, 권장)

```bash
git clone https://github.com/sigco3111/clipboard-history-mac
cd clipboard-history-mac
open Package.swift  # Xcode에서 자동 열림
# Xcode에서: Product → Run (⌘R)
```

Xcode가 자동으로:
- ✅ Swift Package dependencies resolve
- ✅ Scheme `ClipboardHistoryMac` 생성
- ✅ `My Mac` 대상으로 빌드/실행

**결과물**: `~/Library/Developer/Xcode/DerivedData/.../ClipboardHistoryMac.app`

### 방법 B: Swift CLI (빠름)

```bash
# 빌드 (Release, 본인 아키텍처)
swift build -c release

# 실행
.build/release/ClipboardHistoryMac

# Universal binary (arm64 + x86_64)
swift build -c release --arch arm64 --arch x86_64
```

### 방법 C: .app 번들 수동 생성 (CLI 사용자용)

`swift build`는 raw 실행파일만 생성하므로 macOS .app 번들이 필요하면:

```bash
# 1. 빌드
swift build -c release

# 2. .app 번들 수동 생성
APP="ClipboardHistoryMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClipboardHistoryMac "$APP/Contents/MacOS/"
cp Sources/ClipboardHistoryMac/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/ClipboardHistoryMac"

# 3. ad-hoc 서명 (무료, 본인 PC만)
codesign --force --deep --sign - "$APP"

# 4. 실행
open "$APP"
```

## 💾 데이터 저장

```
~/Library/Application Support/ClipboardHistoryMac/
├── entries.json          ← 메타데이터 (id, type, text/hash/ts/size)
└── images/
    ├── abc123.png        ← SHA-256 해시명
    ├── def456.jpg
    └── ...
```

- **로컬만** — 서버 전송 0
- **JSON** — Finder에서 바로 열람 가능
- **이미지** — `<hash>.<ext>` 파일명, 중복 자동 제거

## 🔐 권한 안내

| 작업 | 권한 |
|------|------|
| 메뉴바 상주 | 자동 (LSUIElement) |
| `NSPasteboard` 폴링 | 자동 (사용자 앱) |
| `~/Library/Application Support/` 쓰기 | 자동 |
| 다른 사람에게 .app 배포 | ⚠️ **Apple Developer 계정** ($99/년) |

**본인 macOS에서만 사용** 시 Developer 계정 **불필요**. 위 방법 A~C 모두 무료.

## 🔧 자동 시작 설정 (선택)

빌드된 `.app`을 Applications 폴더로 복사 후:

1. **시스템 설정 → 일반 → 로그인 항목** (macOS 13+)
2. `+` 클릭 → `/Applications/ClipboardHistoryMac.app` 선택
3. 로그인 시 자동 시작

또는 Terminal에서:

```bash
# Applications로 복사
cp -R ~/Library/Developer/Xcode/DerivedData/ClipboardHistoryMac-*/Build/Products/Release/ClipboardHistoryMac.app /Applications/

# Login Item 등록 (AppleScript)
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/ClipboardHistoryMac.app", hidden:false}'
```

## 🛠 기술 스택

- **SwiftUI** (`MenuBarExtra`, `Window`, `List`, `TextField`)
- **AppKit** (`NSPasteboard`, `NSImage`, `NSBitmapImageRep`)
- **CryptoKit** (SHA-256 해시)
- **Combine** (`@Published`, `ObservableObject`)
- **macOS 13.0+** (Ventura 이후 — `MenuBarExtra` API 필요)

## 🔧 트러블슈팅

### "개발자를 확인할 수 없음" 경고
```
Gatekeeper가 서명되지 않은 앱 차단
→ 우클릭 → 열기 → 열기 (한 번만)
```

### 메뉴바에 아이콘이 안 보임
```
시스템 설정 → 제어 센터 → 메뉴바 추가 항목
→ "ClipboardHistoryMac" 활성화
```

### Xcode 빌드 실패: "Minimum deployment target"
```
Project → Target → General → Minimum Deployments
→ macOS 13.0 이상으로 설정
```

### `swift build` 에러: "Module 'SwiftUI' not found"
```bash
# Xcode Command Line Tools가 아닌 전체 Xcode 설치 필요
xcode-select -p
# → /Applications/Xcode.app/Contents/Developer 이어야 함
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 📂 프로젝트 구조

```
clipboard-history-mac/
├── Package.swift                           # Swift Package 매니페스트
├── Sources/ClipboardHistoryMac/
│   ├── ClipboardHistoryMacApp.swift         # @main + MenuBarExtra + Window
│   ├── ClipboardWatcher.swift              # NSPasteboard 폴링 + 중복 방지
│   ├── StorageManager.swift                # 로컬 파일 저장 + SHA-256
│   ├── MenuContentView.swift               # 메뉴바 드롭다운 UI
│   ├── MainWindowView.swift                # 검색 + 목록 + 복원/삭제
│   ├── Info.plist                          # Bundle metadata (LSUIElement)
│   └── ClipboardHistory.entitlements       # Sandbox 비활성화
├── Resources/
│   └── index.html                          # (참고용 — 기존 단일 HTML 버전)
├── LICENSE
└── README.md
```

## 🔗 관련 sigco3111 프로젝트

- [clipboard-history](https://github.com/sigco3111/clipboard-history) — 브라우저 단일 HTML 버전
- [idea-bank](https://github.com/sigco3111/idea-bank) — Productivity Utility #21번에서 출발

## 📄 라이선스

MIT — 자유롭게 사용, 수정, 배포 가능.