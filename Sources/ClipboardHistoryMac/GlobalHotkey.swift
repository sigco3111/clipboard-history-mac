import AppKit
import Carbon

/// Carbon-backed global hotkey. Registers an app-scope key combo via RegisterEventHotKey
/// (no Accessibility permission required) and routes Carbon events back into Swift via a
/// retained reference passed through the event handler.
@MainActor
final class GlobalHotkey: NSObject {
    typealias Handler = () -> Void

    static let signature: FourCharCode = FourCharCode(0x4843_4D4E) // 'HCMN' = Hotkey ClipboardManager

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: Handler?

    @objc(isRegistered)
    var isRegistered: Bool { hotKeyRef != nil }

    /// Register a global hotkey. Returns true on success. Safe to call only once; if
    /// already registered, returns true without rebinding.
    @discardableResult
    @objc(register:modifiers:handler:)
    func register(keyCode: UInt32,
                  modifiers: UInt32,
                  handler: @escaping Handler) -> Bool {
        if hotKeyRef != nil { return true }
        self.handler = handler

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let registeredRef = ref else {
            AppLog.error("RegisterEventHotKey failed with status \(status)")
            return false
        }
        hotKeyRef = registeredRef
        installEventHandler()
        AppLog.info("registered (keyCode=\(keyCode) modifiers=\(modifiers))")
        return true
    }

    @objc(unregister)
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let eh = eventHandlerRef {
            RemoveEventHandler(eh)
            eventHandlerRef = nil
        }
        handler = nil
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(Self.signature),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass self through as a void* userdata so the C callback can recover
        // the GlobalHotkey instance and dispatch its Swift handler.
        let opaque = Unmanaged.passUnretained(self).toOpaque()

        let carbonHandler: EventHandlerUPP = { (_, _, userData) -> OSStatus in
            AppLog.info("Carbon hotkey event fired")
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            // The handler is invoked from the main runloop; dispatch to main if not.
            DispatchQueue.main.async {
                AppLog.info("dispatching handler to main queue")
                manager.handler?()
            }
            return noErr
        }

        var installedHandler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHandler,
            1,
            &eventType,
            opaque,
            &installedHandler
        )
        self.eventHandlerRef = installedHandler
    }

    /// Test seam — bypasses Carbon and invokes the registered handler directly.
    @objc(simulateCarbonEventForTests)
    func simulateCarbonEventForTests() {
        handler?()
    }
}
