# Plan: Fresh restart for the persistent bugs

## Why this plan exists
Two consecutive fix commits (1d8e2c3, 88cece1) failed to satisfy the user:
- Text and image still don't register in history.
- "Open Full History" only ever shows a single permission popup, then nothing.

The user requested a clean restart rather than another patch.

## Reinvestigation
swift build clean, swift test 11/11 PASS, real-binary capture flow works in this env.
The most likely root cause is macOS 14+ pasteboard-read TCC denial. NSPasteboard.general
reads trigger a permission prompt that the user can deny. After denial, subsequent reads
return nil/empty and our watcher silently fails to capture.

## Strategy
Keep the working NSStatusItem + NSMenu architecture from 88cece1. Add:
1. Permission-state detection: log + menu badge that surfaces "권한 필요" when reads are
   denied, instead of silently failing.
2. Visual feedback: "Captured: N" status in the menu so the user knows the watcher is alive.
3. Recent-items submenu using NSMenuItem.title updates (no SwiftUI).
4. Fail-loud approach: any read failure → record and surface immediately.

## Success criteria
- C1: Real binary captures text → entries.json.
- C2: Real binary captures image → entries.json + images/<hash>.png.
- C3: Real binary, NSMenuItem.action invoked → NSApp.windows has title "Clipboard History".
- C4: swift test 11/11 PASS, build clean, regression locks.
- C5: Menu shows a status header ("Captured: N" or "권한 필요").

## Plan
Plan: .omo/plans/clipboard-history-mac-restart.md
