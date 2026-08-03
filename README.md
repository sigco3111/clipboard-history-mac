# 🗂️ Clipboard History macOS

> **macOS 메뉴바 상주형** 클립보드 히스토리 — SwiftUI MenuBarExtra + NSPasteboard 폴링 + 로컬 파일 저장

[![GitHub Actions](https://img.shields.io/badge/build-macos_13%2F14-blue)](.github/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS_13%2B-green)](https://developer.apple.com/macos)
[![Built with SwiftUI](https://img.shields.io/badge/built_with-SwiftUI-orange)](https://developer.apple.com/xcode/swiftui/)

---

## 📌 이 프로젝트는?

기존 [clipboard-history](https://github.com/sigco3111/clipboard-history) (브라우저 단일 HTML)의 **네이티브 macOS 메뉴바 앱** 버전이에요.

### ✨ 차이점

| 항목 | 단일 HTML | macOS 앱 |
|------|----------|----------|
| **메뉴바 상주** | ❌ | ✅ 항상 상주 |
| **자동 시작** | ❌ | ✅ 로그인 시 자동 시작 |
| **시스템 클립보드 직접 접근** | 브라우저 sandbox | `NSPasteboard` native |
| **저장소** | IndexedDB | `~/Library/Application Support/` |
| **GitHub Pages** | ✅ | ❌ (네이티브 앱) |
| **빌드** | 불필요 | Xcode 15+ 필요 |

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

## 🚀 빠른 시작

### 방법 1: GitHub Actions (자동 빌드, 권장)

1. https://github.com/sigco3111/clipboard-history-mac/actions
2. **Build macOS App** 워크플로 → `Run workflow` 클릭
3. 완료 후 **Artifacts**에서 `.zip` 또는 `.dmg` 다운로드
4. 다운로드한 파일 더블클릭 → `ClipboardHistoryMac.app` 추출
5. 첫 실행: 우클릭 → **열기** (Gatekeeper 한 번 우회)
6. 메뉴바에 📋 아이콘 등장

### 방법 2: Xcode에서 직접 빌드 (권장 — 본인 macOS)

```bash
git clone https://github.com/sigco3111/clipboard-history-mac
cd clipboard-history-mac
open Package.swift  # Xcode에서 열기
# Xcode에서: Product → Run (⌘R)
```

빌드 후 `/Users/your-username/Library/Developer/Xcode/DerivedData/.../ClipboardHistoryMac.app` 생성.

### 방법 3: xcodebuild CLI

```bash
# ad-hoc 서명 (무료, 본인 PC만)
xcodebuild \
  -scheme ClipboardHistoryMac \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

# 결과: ./build/Build/Products/Release/ClipboardHistoryMac.app

# ad-hoc 서명 (Gatekeeper 우회)
codesign --force --deep --sign - ./ClipboardHistoryMac.app
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
- **JSON** — macOS Finder에서 바로 열람 가능
- **이미지** — `<hash>.<ext>` 파일명, 중복 자동 제거

## 🔐 권한 안내

| 작업 | 권한 |
|------|------|
| 메뉴바 상주 | 자동 |
| 클립보드 폴링 (`NSPasteboard`) | 자동 (사용자 앱이므로) |
| `~/Library/Application Support/` 쓰기 | 자동 |
| 다른 사람에게 배포 | ⚠️ **Apple Developer 계정** ($99/년) 필요 |

**본인 macOS에서만 사용** 시 Developer 계정 **불필요**. 위 방법 1~3 모두 무료.

## 🔧 자동 시작 설정 (선택)

빌드된 `.app`을 Applications 폴더로 복사 후:

1. **시스템 설정 → 일반 → 로그인 항목** (macOS 13+)
2. `+` 클릭 → `/Applications/ClipboardHistoryMac.app` 선택
3. 로그인 시 자동 시작

또는 코드로:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/ClipboardHistoryMac.app", hidden:false}'
```

## 🛠 기술 스택

- **SwiftUI** (`MenuBarExtra`, `Window`, `List`, `TextField`)
- **AppKit** (`NSPasteboard`, `NSImage`, `NSBitmapImageRep`)
- **CryptoKit** (SHA-256 해시)
- **Combine** (`@Published`, `ObservableObject`)
- **macOS 13.0+** (Ventura 이후 — `MenuBarExtra` API 필요)

## 📦 빌드 산출물

`xcodebuild`로 빌드 시:
- `ClipboardHistoryMac.app` (~10-30 MB)
- 아키텍처: arm64 (Apple Silicon) + x86_64 (Intel)
- 의존성: 시스템 프레임워크만 (Foundation, SwiftUI, AppKit, CryptoKit)

## 🔧 트러블슈팅

### "개발자를 확인할 수 없음" 경고
```
Gatekeeper가 서명되지 않은 앱 차단
→ 우클릭 → 열기 → 열기 (한 번만)
```

### 메뉴바에 아이콘이 안 보임
```
시스템 설정 → 일반 → 메뉴바 추가 항목
→ "ClipboardHistoryMac" 활성화
```

### Xcode 빌드 실패: "Minimum deployment target"
```
Project → Target → General → Minimum Deployments
→ macOS 13.0 이상으로 설정
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
├── .github/workflows/build.yml             # GitHub Actions 자동 빌드
├── LICENSE
└── README.md
```

## 🔗 관련 sigco3111 프로젝트

- [clipboard-history](https://github.com/sigco3111/clipboard-history) — 브라우저 단일 HTML 버전
- [idea-bank](https://github.com/sigco3111/idea-bank) — Productivity Utility #21번에서 출발

## 📄 라이선스

MIT — 자유롭게 사용, 수정, 배포 가능.