# 🗂️ Clipboard History macOS

> **macOS 메뉴바 상주형** 클립보드 히스토리 — `NSPasteboard` 폴링 + 로컬 JSON 저장 + Cmd+V로 클립보드 복구

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS_13%2B-green)](https://developer.apple.com/macos)
[![Swift 5.9+](https://img.shields.io/badge/swift-5.9%2B-blue)](https://swift.org)

`gitco3111 / clipboard-history-mac` — A native macOS menu-bar clipboard history utility.

`clipboard-history` 웹 단일 HTML 버전의 네이티브 macOS 메뉴바 앱. 텍스트와 이미지를 자동 캡처해서 검색·재사용 가능.

---

## ✨ 기능

- **자동 캡처**: `NSPasteboard.general` 1초 폴링. 텍스트와 이미지 모두 저장.
- **이미지 디스크 저장**: `~/Library/Application Support/ClipboardHistoryMac/images/<sha>.png`. 동일 SHA는 중복 제거.
- **메뉴바에서 빠른 조회**: 캡처 카운트 + 상태 헤더 + 최근 텍스트 3개 + 최근 이미지 3개.
- **한 번 클릭으로 재복사**: 최근 텍스트/이미지 메뉴 항목을 클릭하면 그 항목이 pasteboard에 다시 들어감. 다른 앱에서 `Cmd+V`.
- **메인 윈도우**: 전체 히스토리 검색·열람·복사·삭제. 항목별 Delete 버튼.
- **권한 상태 표시**: pasteboard-read TCC가 거부되면 메뉴에 "⚠️ 클립보드 권한 필요" 헤더 노출.
- **권한 불필요**: Carbon global hotkey나 Accessibility 등 추가 권한 요구 0. 메뉴바 클릭과 더블 클릭만으로 모든 기능 가능.

## 🎯 UX

```
[메뉴바 상태바 — 📋 N]
   │
   ├─ 한 번 클릭 → 메뉴 표시
   │     ├─ 캡처: 총 N개 (텍스트 T · 이미지 I)
   │     ├─ (필요시) ⚠️ 클립보드 권한 경고
   │     ├─ 최근 텍스트 (클릭 시 pasteboard 재복사)
   │     ├─ 최근 이미지 (클릭 시 pasteboard 재복사)
   │     ├─ [전체 히스토리 열기] → 메인 윈도우
   │     ├─ [지금 새로 캡처]  [자동 캡처 일시정지/재개]
   │     ├─ [GitHub] [종료]
   │
   └─ 더블 클릭 → 메인 윈도우 즉시 열기
```

- `Cmd+V` (다른 앱)을 누르면 마지막에 캡처한 항목이 자동으로 pasteboard에 복원되어 어디든 붙여넣기 가능
- 1초 단위 폴링이라 키스트로크 누르는 즉시 깨닫고 캡처 (실제 사용자 체감 ≈ 즉시)

## 🚀 빌드 & 실행

### ⚙️ 요구사항
- **macOS 13.0+** (Ventura 이후)
- **Xcode 15+** 또는 **Swift 5.9+** Command Line Tools
- Apple Developer 계정 불필요 (본인 macOS 사용 시)

### 방법 A — Xcode (권장)

```bash
git clone https://github.com/sigco3111/clipboard-history-mac
cd clipboard-history-mac
open Package.swift   # Xcode 자동 열림
# Xcode에서: Product → Run (⌘R)
```

Xcode가 자동으로 scheme `ClipboardHistoryMac`을 생성하고 `My Mac`으로 빌드/실행합니다.
Launch Services가 빌드를 흡수해 `DerivedData/.../ClipboardHistoryMac.app`에 넣습니다.

### 방법 B — Swift CLI

```bash
swift build -c release
./.build/release/ClipboardHistoryMac
# 또는 Universal binary:
swift build -c release --arch arm64 --arch x86_64
```

### 방법 C — .app 번들 수동 (Finder 더블 클릭으로 launch)

```bash
swift build -c release
APP="ClipboardHistoryMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClipboardHistoryMac "$APP/Contents/MacOS/"
cp Sources/ClipboardHistoryMac/Info.plist "$APP/Contents/"
chmod +x "$APP/Contents/MacOS/ClipboardHistoryMac"
codesign --force --deep --sign - "$APP"   # ad-hoc 서명
open "$APP"
```

## 💾 데이터 저장

```
~/Library/Application Support/ClipboardHistoryMac/
├── entries.json          ← 메타데이터 (id, type, text/hash/ts/size/mime)
└── images/
    ├── abc123...png      ← 이미지 바이너리, SHA-256 해시 파일명
    ├── def456...jpg
    └── ...

~/Library/Logs/ClipboardHistoryMac.log  ← AppLog(os.Logger + 파일 write queue)
```

- **로컬만** — 서버 전송 0
- **JSON** — Finder에서 바로 열람 가능
- **이미지 중복 자동 제거** — 동일 SHA는 한 번만 디스크에 저장

### 데이터 초기화 (전체 삭제)

```bash
rm -rf ~/Library/Application\ Support/ClipboardHistoryMac
rm -f ~/Library/Logs/ClipboardHistoryMac.log
```

## 🧰 메뉴 항목 상세

| 항목 | 동작 |
|------|------|
| 캡처: 총 N개 ... | (헤더 — 비활성, 캡처 상태 표시) |
| ⚠️ 클립보드 권한 필요 | (조건부 헤더 — macOS 14+ TCC 거부 시 노출. 시스템 설정 → 개인 정보 보호 → 클립보드 → ClipboardHistoryMac 허용) |
| 최근 텍스트 (최대 3) | 클릭 시 그 텍스트를 `NSPasteboard.general`에 다시 복사 |
| 최근 이미지 (최대 3) | 클릭 시 그 이미지를 `NSPasteboard.general`에 다시 복사. 다른 앱에서 `Cmd+V`로 붙여넣기 |
| 전체 히스토리 열기 | 메인 윈도우 오픈 |
| 지금 새로 캡처 | 다음 pasteboard 변경까지 기다리지 않고 즉시 1회 캡처 시도 |
| 자동 캡처 일시정지 / 재개 | 폴링 토글. 재개 시 다음 change까지 대기 시간 갱신 |
| GitHub (단일 HTML 버전) | 브라우저에서 `https://github.com/sigco3111/clipboard-history` |
| 종료 | `Cmd+Q` 단축키 |

### 상태바 더블 클릭

`NSStatusItem.button`에 `leftMouseDown` 핸들러를 걸고 `CACurrentMediaTime`로 더블 클릭 윈도우(0.35s) 내 두 번째 클릭이면 `openMainWindow(nil)`을 호출합니다. 권한 없이 항상 동작.

## 🔍 디버그 / 진단

### 로그 파일

```bash
tail -f ~/Library/Logs/ClipboardHistoryMac.log
```

`Logging.swift`가 os.Logger와 파일 쓰기 큐(직렬화)로 매 이벤트(Carbon 등록, 윈도우 오픈, pasteboard 이벤트 등)를 타임스탬프와 함께 기록합니다. Carbon hotkey가 없는 대신 어떻게 동작하는지 명확하게 추적할 수 있습니다.

### 1회성 진단 launch flag

| Flag | 동작 |
|------|------|
| `--ulw-fire-open` | launch 1.5초 후 `openMainWindow(nil)` 호출 (메뉴 클릭과 같은 경로). 메뉴가 동작 안 할 때 open-pipeline 진단 |

## 🔐 권한 안내

| 작업 | 권한 |
|------|------|
| 메뉴바 상주 (LSUIElement) | 자동 |
| `NSPasteboard` 자동 캡처 | 시스템 — macOS 14+에서는 첫 캡처 시 권한 팝업 1회 |
| `~/Library/Application Support` 쓰기 | 자동 |
| 다른 사람에게 .app 배포 | ⚠️ Apple Developer 계정 ($99/년) |

본인 macOS에서만 사용 시 Developer 계정 불필요. 위 방법 A~C 모두 무료.

## 🔧 자동 시작 (Login Item)

빌드된 `.app`을 `~/Applications/`(또는 `/Applications`)에 복사 후:

1. 시스템 설정 → 일반 → 로그인 항목 → `+` → `ClipboardHistoryMac.app` 선택
2. 로그인 시 자동 시작 + 메뉴바 상주

또는 AppleScript:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/ClipboardHistoryMac.app", hidden:false}'
```

## 🛠 기술 스택

- **SwiftUI** (`Settings` scene, `App` lifecycle)
- **AppKit** (`NSPasteboard`, `NSImage`, `NSBitmapImageRep`, `NSStatusItem`, `NSStatusBar`, `NSMenu`, `NSMenuItem`, `NSHostingController`, `NSWindowController`, `NSWindow`, `NSScreen`, `NSWorkspace`)
- **CryptoKit** (SHA-256)
- **Combine** (`ObservableObject`, `@Published`, `objectWillChange`)
- **os.log + DispatchQueue** (`AppLog`, 파일 기반 진단)
- **macOS 13.0+**

## 📂 프로젝트 구조

```
clipboard-history-mac/
├── Package.swift                           # Swift Package 매니페페스트 (SwiftPM test target 포함)
├── Sources/ClipboardHistoryMac/
│   ├── ClipboardHistoryMacApp.swift         # @main + @NSApplicationDelegateAdaptor + NSStatusItem
│   ├── Logging.swift                        # os.Logger + 파일 쓰기 큐 (~/Library/Logs/...)
│   ├── ClipboardWatcher.swift              # NSPasteboard 폴링 + 중복 방지 + 권한 상태
│   ├── StorageManager.swift                # 로컬 파일 저장 + SHA-256
│   ├── MainWindowView.swift                # 검색 + 목록 + 복사/삭제
│   ├── Info.plist                          # LSUIElement bundle metadata
│   └── ClipboardHistory.entitlements       # Sandbox 비활성화
├── Tests/ClipboardHistoryMacTests/
│   ├── StorageManagerTests.swift           # 디스크 영속성 + dedup
│   ├── ClipboardWatcherTests.swift         # 텍스트/이미지 capture + dedup + auto-start
│   ├── StatusMenuTests.swift               # NSMenu 라우팅 + 권한 UI + double-click + recent items re-copy
│   ├── WatcherIssueTests.swift            # (in ClipboardWatcherTests) TCC 거부 signature
│   └── Helpers/TestStorage.swift           # 디스크 격리 helper
├── LICENSE
└── README.md
```

### 테스트

```bash
swift test
# 현재 23 tests:
#   StorageManagerTests  (디스크 + dedup)               : 4 tests
#   WatcherIssueTests    (권한 거부 signature)         : 2 tests
#   ClipboardWatcherTests (이미지 capture, dedup, start): 3 tests
#   StatusMenuTests      (메뉴 wiring + 로그)          : 14 tests
```

## 🔗 관련 프로젝트

- [clipboard-history](https://github.com/sigco3111/clipboard-history) — 브라우저 단일 HTML 버전
- [idea-bank](https://github.com/sigco3111/idea-bank) — Productivity Utility #21

## 📄 라이선스

MIT
