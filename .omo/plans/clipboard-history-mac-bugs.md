# Plan: Fix 3 bugs in clipboard-history-mac

## Goal
1. Image clipboard items not saved.
2. Remove Capture button; always auto-save.
3. "Open Full History" button does nothing.

## Root causes (to verify with RED tests)
- RC-1: `ClipboardWatcher.start()` is only called from `MainWindowView.onAppear`. If the main
  window is never opened (currently blocked by Bug 3), the timer never fires.
- RC-2: `MenuContentView`'s "Open Full History" mutates a `showMainWindow` Bool that nothing
  reads. SwiftUI Window scenes need `@Environment(\.openWindow)`.
- RC-3: `captureImage()` TIFF→PNG path has a redundant `NSImage(data:)` step that masks failures
  from `NSBitmapImageRep(data:)`. Also misses `.pdf`.

## Success criteria
1. Watcher auto-starts — no manual `start()` required.
2. Image save works end-to-end (pasteboard image → disk + entries.json entry).
3. "Open Full History" menu item opens the main window — manual launch + AppleScript proof.
4. "지금 캡처" buttons removed from both views; `captureNow()` callers gone.
5. StorageManager image persistence round-trip across instances (regression lock).

## Plan
Tests target setup → RED tests → GREEN fixes → surface proofs → cleanup → reviewer.

Plan: .omo/plans/clipboard-history-mac-bugs.md
