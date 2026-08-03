# Plan: Open Full History actually opens the window

## Why this plan exists
The previously shipped "fix" (e2233fb) changed `showMainWindow = true` to `openWindow(id: "main")`,
verified by a source-text presence test plus a SEPARATE Probe app that proved SwiftUI can open
a "Clipboard History" window from `openWindow(id: "main")`. Neither test exercises the real
production app's MenuBarExtra-popup → Window-scene wire.

## Reachable hypotheses
H1 — `openWindow` env-injected into MenuBarExtra's `.window`-styled popup does not resolve to
     the sibling Window scene in our App body on macOS 13+.
H2 — `Window(id: "main")` is single-instance; auto-presentation requires the receiving scene to
     already exist on screen at least once, or the openWindow is silently dropped.
H3 — The `openWindow(id:)` action is invoked but `NSApp.activate(ignoringOtherApps: true)` runs
     too early and is undone by the LSUIElement activation policy before SwiftUI can present.
H4 — Scene ID "main" collides with a SwiftUI-reserved name.

## Success criteria
1. Pre-fix binary check: programmatic invocation of the same action the button does
   (via `--ulw-open-main` flag) does NOT create a window titled "Clipboard History".
2. Root-cause: file:line or runtime observation pinning one of H1-H4.
3. Post-fix binary check: same flag invocation produces a window titled "Clipboard History".
4. Regression: 10 swift tests green, capture button absent, auto-start works.

Plan: .omo/plans/clipboard-history-mac-open-main.md
