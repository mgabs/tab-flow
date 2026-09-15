import Carbon.HIToolbox.Events
import ShortcutRecorder

/// Registers push-to-talk's global hold-shortcut directly via Carbon, independent of
/// `KeyboardEvents`/`ControlsTab.shortcuts`/`ATShortcut`. Those are session-gated
/// (`ATShortcut.shouldTrigger()` checks `SwitcherSession.current`) and dispatch through
/// `ShortcutActions.execute(id)`; push-to-talk must fire identically whether or not the switcher
/// is open, so it owns its own `EventHotKeyID` namespace and handler pair.
class PushToTalkHotkey {
    private static let signature: OSType = "atpt".utf16.reduce(0) { ($0 << 8) + OSType($1) }
    private static let hotkeyId = EventHotKeyID(signature: signature, id: 1)
    private static let eventTarget = GetEventDispatcherTarget()
    private static var hotKeyRef: EventHotKeyRef?
    private static var pressedHandler: EventHandlerRef?
    private static var releasedHandler: EventHandlerRef?
    private static var onPress: (() -> Void)?
    private static var onRelease: (() -> Void)?

    static func register(_ shortcut: Shortcut, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        unregister()
        guard shortcut.keyCode != .none else { return }
        self.onPress = onPress
        self.onRelease = onRelease
        installHandlersIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.carbonKeyCode, shortcut.carbonModifierFlags, hotkeyId, eventTarget, UInt32(kEventHotKeyNoOptions), &ref)
        if status == noErr {
            hotKeyRef = ref
            Logger.debug { "registered pushToTalkShortcut keyCode:\(shortcut.carbonKeyCode) modifiers:\(shortcut.carbonModifierFlags)" }
        } else {
            Logger.error { "RegisterEventHotKey failed for pushToTalkShortcut status:\(status)" }
        }
    }

    static func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private static func installHandlersIfNeeded() {
        if pressedHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
            InstallEventHandler(eventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard id.signature == PushToTalkHotkey.signature && id.id == PushToTalkHotkey.hotkeyId.id else { return OSStatus(eventNotHandledErr) }
                PushToTalkHotkey.onPress?()
                return noErr
            }, eventTypes.count, &eventTypes, nil, &pressedHandler)
        }
        if releasedHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            InstallEventHandler(eventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard id.signature == PushToTalkHotkey.signature && id.id == PushToTalkHotkey.hotkeyId.id else { return OSStatus(eventNotHandledErr) }
                PushToTalkHotkey.onRelease?()
                return noErr
            }, eventTypes.count, &eventTypes, nil, &releasedHandler)
        }
    }
}
