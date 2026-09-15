# Push-to-talk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a free, opt-in push-to-talk feature: while armed (menu bar toggle), AltTab keeps the
system's default microphone muted; holding a configurable global shortcut temporarily unmutes it
(and releasing re-mutes it), with a small on-screen HUD while talking.

**Architecture:** A pure state machine (`PushToTalkControllerTestable`) decides transitions and
side-effects for events (arm/disarm/key-down/key-up/device-changed); `PushToTalkController` is a
thin AppKit/CoreAudio glue layer that executes those side-effects through a CoreAudio wrapper
(`PushToTalkAudioDevice`, behind `PushToTalkAudioDeviceProtocol` for testability) and drives the
menu bar item, icon state, and HUD. The global hold-shortcut is captured by a **standalone** Carbon
`RegisterEventHotKey`/`InstallEventHandler` pair (`PushToTalkHotkey`) — deliberately **not** routed
through `ControlsTab.shortcuts`/`ATShortcut`/`KeyboardEvents`, because that machinery is
session-gated (`ATShortcut.shouldTrigger()` checks `SwitcherSession.current`) and dispatches through
`ShortcutActions.execute(id)`, neither of which push-to-talk needs or wants — push-to-talk must fire
identically whether or not the switcher is open. The Preferences UI still reuses the existing
`CustomRecorderControl` widget and the generic `Preferences.setShortcut`/`shortcut(_:)` storage
(that read/write path is not `ControlsTab`-specific), so the shortcut still looks and behaves like
every other AltTab shortcut in Settings.

**Tech Stack:** Swift 5.8, AppKit (`NSPanel`, `NSMenuItem`, `NSVisualEffectView`), Carbon
(`Carbon.HIToolbox.Events`: `RegisterEventHotKey`/`InstallEventHandler`, same APIs already used in
`src/events/KeyboardEvents.swift`), CoreAudio/AudioToolbox (`AudioObjectGetPropertyData`/
`AudioObjectSetPropertyData`/`AudioObjectAddPropertyListenerBlock`), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-11-push-to-talk-design.md`

## Global Constraints

- Free feature: no Pro gating, no `ProFeature`/`LicenseManager` checks anywhere in this plan.
- Armed/talking state is **in-memory only** — never written to `UserDefaults` — so every launch
  starts disarmed. The `pushToTalkShortcut` *shortcut binding* itself does persist, like any other
  shortcut preference.
- Muting is system-wide (default CoreAudio input device), never per-app/simulated-click.
- Arm/disarm is an explicit, visible menu bar toggle — never silently auto-armed.
- Hardware mute (`kAudioDevicePropertyMute`) is tried first; if unsupported, fall back to saving and
  zeroing `kAudioDevicePropertyVolumeScalar`, restoring the saved value later.
- `applicationWillTerminate` must restore the original device state if still armed (best-effort;
  cannot cover `SIGKILL`, matching the existing crash posture in `src/main.swift`).
- Known, accepted limitation (not a task in this plan): the push-to-talk shortcut is not
  conflict-checked against other AltTab shortcuts (the `ControlsTab` conflict dialog only covers
  shortcuts registered in its own `shortcuts` registry). Documented in the spec's "Open risks".

---

### Task 1: `PushToTalkControllerTestable` — pure state machine

**Files:**
- Create: `src/push-to-talk/PushToTalkControllerTestable.swift`
- Create: `src/push-to-talk/PushToTalkControllerTestableSpecs.md`
- Test: `src/push-to-talk/PushToTalkControllerTestableTests.swift`

**Interfaces:**
- Produces (consumed by Task 3's `PushToTalkController`):
  - `PushToTalkControllerTestable.State`: enum `{ disarmed, armedMuted, armedTalking }`
  - `PushToTalkControllerTestable.Event`: enum `{ arm, disarm, keyDown, keyUp, defaultDeviceChanged }`
  - `PushToTalkControllerTestable.SideEffect`: enum `{ captureAndMute, restoreOriginal, unmute,
    reMute, reMuteThenRestore, reapplyCurrentPolicy, none }`
  - `PushToTalkControllerTestable.Transition`: struct `{ let nextState: State; let sideEffect:
    SideEffect }`
  - `static func transition(_ state: State, _ event: Event) -> Transition`

- [ ] **Step 1: Write the failing tests**

Create `src/push-to-talk/PushToTalkControllerTestableTests.swift`:

```swift
import XCTest
@testable import AltTab

class PushToTalkControllerTestableTests: XCTestCase {
    typealias State = PushToTalkControllerTestable.State
    typealias Event = PushToTalkControllerTestable.Event
    typealias SideEffect = PushToTalkControllerTestable.SideEffect

    private func assertTransition(_ state: State, _ event: Event, _ expectedState: State, _ expectedSideEffect: SideEffect, file: StaticString = #filePath, line: UInt = #line) {
        let result = PushToTalkControllerTestable.transition(state, event)
        XCTAssertEqual(result.nextState, expectedState, file: file, line: line)
        XCTAssertEqual(result.sideEffect, expectedSideEffect, file: file, line: line)
    }

    // disarmed
    func test_disarmed_arm_capturesAndMutes() {
        assertTransition(.disarmed, .arm, .armedMuted, .captureAndMute)
    }

    func test_disarmed_disarm_isNoop() {
        assertTransition(.disarmed, .disarm, .disarmed, .none)
    }

    func test_disarmed_keyDown_isNoop() {
        assertTransition(.disarmed, .keyDown, .disarmed, .none)
    }

    func test_disarmed_keyUp_isNoop() {
        assertTransition(.disarmed, .keyUp, .disarmed, .none)
    }

    func test_disarmed_defaultDeviceChanged_isNoop() {
        assertTransition(.disarmed, .defaultDeviceChanged, .disarmed, .none)
    }

    // armedMuted
    func test_armedMuted_arm_isNoop() {
        assertTransition(.armedMuted, .arm, .armedMuted, .none)
    }

    func test_armedMuted_disarm_restoresOriginal() {
        assertTransition(.armedMuted, .disarm, .disarmed, .restoreOriginal)
    }

    func test_armedMuted_keyDown_unmutes() {
        assertTransition(.armedMuted, .keyDown, .armedTalking, .unmute)
    }

    func test_armedMuted_keyUp_isNoop() {
        assertTransition(.armedMuted, .keyUp, .armedMuted, .none)
    }

    func test_armedMuted_defaultDeviceChanged_reappliesPolicy() {
        assertTransition(.armedMuted, .defaultDeviceChanged, .armedMuted, .reapplyCurrentPolicy)
    }

    // armedTalking
    func test_armedTalking_arm_isNoop() {
        assertTransition(.armedTalking, .arm, .armedTalking, .none)
    }

    func test_armedTalking_disarm_reMutesThenRestores() {
        assertTransition(.armedTalking, .disarm, .disarmed, .reMuteThenRestore)
    }

    func test_armedTalking_keyDown_isNoop() {
        // a repeated/duplicate key-down while already talking must not re-fire unmute
        assertTransition(.armedTalking, .keyDown, .armedTalking, .none)
    }

    func test_armedTalking_keyUp_reMutes() {
        assertTransition(.armedTalking, .keyUp, .armedMuted, .reMute)
    }

    func test_armedTalking_defaultDeviceChanged_reappliesPolicy() {
        assertTransition(.armedTalking, .defaultDeviceChanged, .armedTalking, .reapplyCurrentPolicy)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ai/build.sh && bash ai/test.sh 2>&1 | grep -i "pushtotalk\|error"` (or, if the repo's test
runner is `bundle exec fastlane test`, use that). Expected: compile error — `PushToTalkControllerTestable`
does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `src/push-to-talk/PushToTalkControllerTestable.swift`:

```swift
/// Pure decision logic for the push-to-talk state machine.
/// No singletons, no CoreAudio, no UI, no side effects — just inputs → outputs.
/// See `PushToTalkControllerTestableSpecs.md` for the full transition table.
struct PushToTalkControllerTestable {
    enum State: Equatable {
        case disarmed
        case armedMuted
        case armedTalking
    }

    enum Event: Equatable {
        case arm
        case disarm
        case keyDown
        case keyUp
        case defaultDeviceChanged
    }

    enum SideEffect: Equatable {
        /// arm: snapshot the default device's current mute/volume state, then mute it.
        case captureAndMute
        /// disarm (from armedMuted): restore exactly what `captureAndMute` snapshotted.
        case restoreOriginal
        /// armedMuted -> armedTalking: unmute (or restore saved volume).
        case unmute
        /// armedTalking -> armedMuted: re-mute (or re-zero volume).
        case reMute
        /// disarm (from armedTalking): re-mute first, then restore the original snapshot.
        case reMuteThenRestore
        /// default input device changed while armed: re-snapshot + re-apply the current
        /// sub-state's mute policy to the new device.
        case reapplyCurrentPolicy
        case none
    }

    struct Transition: Equatable {
        let nextState: State
        let sideEffect: SideEffect
    }

    static func transition(_ state: State, _ event: Event) -> Transition {
        switch (state, event) {
        case (.disarmed, .arm):
            return Transition(nextState: .armedMuted, sideEffect: .captureAndMute)
        case (.disarmed, .disarm), (.disarmed, .keyDown), (.disarmed, .keyUp), (.disarmed, .defaultDeviceChanged):
            return Transition(nextState: .disarmed, sideEffect: .none)

        case (.armedMuted, .arm):
            return Transition(nextState: .armedMuted, sideEffect: .none)
        case (.armedMuted, .disarm):
            return Transition(nextState: .disarmed, sideEffect: .restoreOriginal)
        case (.armedMuted, .keyDown):
            return Transition(nextState: .armedTalking, sideEffect: .unmute)
        case (.armedMuted, .keyUp):
            return Transition(nextState: .armedMuted, sideEffect: .none)
        case (.armedMuted, .defaultDeviceChanged):
            return Transition(nextState: .armedMuted, sideEffect: .reapplyCurrentPolicy)

        case (.armedTalking, .arm):
            return Transition(nextState: .armedTalking, sideEffect: .none)
        case (.armedTalking, .disarm):
            return Transition(nextState: .disarmed, sideEffect: .reMuteThenRestore)
        case (.armedTalking, .keyDown):
            return Transition(nextState: .armedTalking, sideEffect: .none)
        case (.armedTalking, .keyUp):
            return Transition(nextState: .armedMuted, sideEffect: .reMute)
        case (.armedTalking, .defaultDeviceChanged):
            return Transition(nextState: .armedTalking, sideEffect: .reapplyCurrentPolicy)
        }
    }
}
```

Create `src/push-to-talk/PushToTalkControllerTestableSpecs.md`:

```markdown
# PushToTalkControllerTestable

Pure state-transition table for push-to-talk. States: `disarmed`, `armedMuted`, `armedTalking`.
Events: `arm`, `disarm`, `keyDown`, `keyUp`, `defaultDeviceChanged`.

- `disarmed` + `arm` -> `armedMuted`, capture the default device's original mute/volume state then mute it.
- `disarmed` + `disarm`/`keyDown`/`keyUp`/`defaultDeviceChanged` -> `disarmed`, no-op (nothing armed yet).
- `armedMuted` + `arm` -> `armedMuted`, no-op (already armed; arming twice must not re-snapshot over a live capture).
- `armedMuted` + `disarm` -> `disarmed`, restore the original snapshot from `arm`.
- `armedMuted` + `keyDown` -> `armedTalking`, unmute (or restore saved volume if hardware mute is unsupported).
- `armedMuted` + `keyUp` -> `armedMuted`, no-op (already up; a duplicate/late key-up must not double-mute).
- `armedMuted` + `defaultDeviceChanged` -> `armedMuted`, re-snapshot + re-apply the muted policy to the new default device.
- `armedTalking` + `arm` -> `armedTalking`, no-op (already armed).
- `armedTalking` + `disarm` -> `disarmed`, re-mute first, then restore the original snapshot (so the device isn't left unmuted mid-restore).
- `armedTalking` + `keyDown` -> `armedTalking`, no-op (a repeated/duplicate key-down while already talking must not re-fire unmute).
- `armedTalking` + `keyUp` -> `armedMuted`, re-mute (or re-zero volume).
- `armedTalking` + `defaultDeviceChanged` -> `armedTalking`, re-snapshot + re-apply the talking (unmuted) policy to the new default device.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash ai/build.sh && bash ai/test.sh 2>&1 | grep -i "pushtotalk"` (adjust to whichever test
command the repo currently uses — see `docs/contributing.md` "Releasing the project" section for
`bundle exec fastlane test`). Expected: all 15 `PushToTalkControllerTestableTests` pass.

- [ ] **Step 5: Register the new files in the Xcode project and commit**

Add the 3 new files to `alt-tab-macos.xcodeproj/project.pbxproj` (main app target for the `.swift`
implementation file, test target for the `Tests.swift` file; the `.md` spec doesn't need a build
phase entry, only a `PBXFileReference`/group entry so it shows in Xcode). Generate new 24-char
uppercase-hex IDs via `python3 -c "import secrets; print(secrets.token_hex(12).upper())"` for each
of the 4 required entries per file (PBXBuildFile, PBXFileReference, PBXGroup children, and the
relevant PBXSourcesBuildPhase/PBXResourcesBuildPhase `files` list).

```bash
git add src/push-to-talk/PushToTalkControllerTestable.swift \
        src/push-to-talk/PushToTalkControllerTestableSpecs.md \
        src/push-to-talk/PushToTalkControllerTestableTests.swift \
        alt-tab-macos.xcodeproj/project.pbxproj
git commit -m "feat: add push-to-talk state machine"
```

---

### Task 2: `PushToTalkAudioDevice` — CoreAudio wrapper

**Files:**
- Create: `src/push-to-talk/PushToTalkAudioDevice.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces (consumed by Task 3):
  - `protocol PushToTalkAudioDeviceProtocol: AnyObject` with:
    - `func defaultInputDeviceID() -> AudioDeviceID?`
    - `func isMuteSupported(_ deviceID: AudioDeviceID) -> Bool`
    - `func getMute(_ deviceID: AudioDeviceID) -> Bool`
    - `func setMute(_ deviceID: AudioDeviceID, _ muted: Bool)`
    - `func getVolume(_ deviceID: AudioDeviceID) -> Float32?`
    - `func setVolume(_ deviceID: AudioDeviceID, _ volume: Float32)`
    - `func observeDefaultInputDeviceChanges(_ handler: @escaping () -> Void)`
  - `class PushToTalkAudioDevice: PushToTalkAudioDeviceProtocol` — the real CoreAudio
    implementation, constructed with no arguments (`PushToTalkAudioDevice()`).

This wrapper talks to real hardware, so — matching how `ProTransitionManager` (AppKit/timer glue) is
integration-only while `ProTransitionManagerTestable` (pure) is unit tested — it is **not** unit
tested here; it's exercised through the manual QA steps in Task 8. Its methods are simple 1:1
CoreAudio property calls, kept intentionally small so the manual QA surface is easy to reason about.

- [ ] **Step 1: Write the implementation**

Create `src/push-to-talk/PushToTalkAudioDevice.swift`:

```swift
import CoreAudio
import AudioToolbox

protocol PushToTalkAudioDeviceProtocol: AnyObject {
    func defaultInputDeviceID() -> AudioDeviceID?
    func isMuteSupported(_ deviceID: AudioDeviceID) -> Bool
    func getMute(_ deviceID: AudioDeviceID) -> Bool
    func setMute(_ deviceID: AudioDeviceID, _ muted: Bool)
    func getVolume(_ deviceID: AudioDeviceID) -> Float32?
    func setVolume(_ deviceID: AudioDeviceID, _ volume: Float32)
    func observeDefaultInputDeviceChanges(_ handler: @escaping () -> Void)
}

/// Thin, 1:1 CoreAudio property wrapper. Kept deliberately dumb: all policy (what to snapshot, when
/// to fall back to volume) lives in `PushToTalkController`, driven by `PushToTalkControllerTestable`.
class PushToTalkAudioDevice: PushToTalkAudioDeviceProtocol {
    private var changeHandler: (() -> Void)?

    private var defaultInputDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    }

    private var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    }

    func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultInputDeviceAddress, 0, nil, &size, &deviceID)
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    func isMuteSupported(_ deviceID: AudioDeviceID) -> Bool {
        var address = muteAddress
        return AudioObjectHasProperty(deviceID, &address)
    }

    func getMute(_ deviceID: AudioDeviceID) -> Bool {
        var address = muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return value != 0
    }

    func setMute(_ deviceID: AudioDeviceID, _ muted: Bool) {
        var address = muteAddress
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    func getVolume(_ deviceID: AudioDeviceID) -> Float32? {
        var address = volumeAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    func setVolume(_ deviceID: AudioDeviceID, _ volume: Float32) {
        var address = volumeAddress
        var value = volume
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    func observeDefaultInputDeviceChanges(_ handler: @escaping () -> Void) {
        changeHandler = handler
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputDeviceAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.changeHandler?()
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`. `CoreAudio`/`AudioToolbox` are system
frameworks; like `Carbon.HIToolbox.Events` (already imported elsewhere in this codebase with no
extra `project.pbxproj` linker entry), no explicit framework-linking change is expected — if the
build instead fails with an unresolved-symbol/linker error, add `CoreAudio.framework` and
`AudioToolbox.framework` to the main app target's `PBXFrameworksBuildPhase` in
`alt-tab-macos.xcodeproj/project.pbxproj` (same 4-entry pattern as any other framework there) and
re-run.

- [ ] **Step 3: Register the new file in the Xcode project and commit**

Add `PushToTalkAudioDevice.swift` to `alt-tab-macos.xcodeproj/project.pbxproj` (main app target),
same 4-entry pattern as Task 1.

```bash
git add src/push-to-talk/PushToTalkAudioDevice.swift alt-tab-macos.xcodeproj/project.pbxproj
git commit -m "feat: add CoreAudio wrapper for push-to-talk"
```

---

### Task 3: `PushToTalkHotkey` — standalone Carbon global hotkey

**Files:**
- Create: `src/push-to-talk/PushToTalkHotkey.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (only `ShortcutRecorder.Shortcut`, already a project
  dependency used throughout `src/preferences`/`src/events`).
- Produces (consumed by Task 4):
  - `class PushToTalkHotkey` with:
    - `static func register(_ shortcut: Shortcut, onPress: @escaping () -> Void, onRelease: @escaping () -> Void)`
    - `static func unregister()`

Deliberately independent of `KeyboardEvents`/`ControlsTab.shortcuts`/`ATShortcut` — see the plan's
Architecture section for why. Not unit tested: `KeyboardEvents.swift`'s equivalent raw
`RegisterEventHotKey`/`InstallEventHandler` calls have no direct unit tests either in this codebase
(only the higher-level `handleKeyboardEvent`/`ATShortcut.matches` logic is tested); this file has no
comparable pure-decision logic to extract, it's a direct Carbon API wrapper.

- [ ] **Step 1: Write the implementation**

Create `src/push-to-talk/PushToTalkHotkey.swift`:

```swift
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
                if id.signature == PushToTalkHotkey.signature && id.id == PushToTalkHotkey.hotkeyId.id {
                    PushToTalkHotkey.onPress?()
                }
                return noErr
            }, eventTypes.count, &eventTypes, nil, &pressedHandler)
        }
        if releasedHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            InstallEventHandler(eventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                if id.signature == PushToTalkHotkey.signature && id.id == PushToTalkHotkey.hotkeyId.id {
                    PushToTalkHotkey.onRelease?()
                }
                return noErr
            }, eventTypes.count, &eventTypes, nil, &releasedHandler)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Register the new file in the Xcode project and commit**

```bash
git add src/push-to-talk/PushToTalkHotkey.swift alt-tab-macos.xcodeproj/project.pbxproj
git commit -m "feat: add standalone global hotkey for push-to-talk"
```

---

### Task 4: `PushToTalkController` — AppKit/CoreAudio glue

**Files:**
- Create: `src/push-to-talk/PushToTalkController.swift`

**Interfaces:**
- Consumes:
  - `PushToTalkControllerTestable.{State, Event, SideEffect, Transition}`, `.transition(_:_:)` (Task 1)
  - `PushToTalkAudioDeviceProtocol`, `PushToTalkAudioDevice()` (Task 2)
  - `PushToTalkHotkey.register(_:onPress:onRelease:)`, `.unregister()` (Task 3)
  - `Menubar.refreshPushToTalkMenuItem(isArmed:isTalking:)` (Task 6 — forward reference; stub it out
    in Task 4 as a call that will compile once Task 6 lands, or land Task 6's `Menubar` method
    first if executing tasks out of order)
  - `PushToTalkHUD.setVisible(_:)` (Task 5)
  - `Preferences.pushToTalkShortcut` (Task 7)
- Produces (consumed by Task 6/7/8):
  - `class PushToTalkController` with:
    - `static let shared: PushToTalkController`
    - `var isArmed: Bool`, `var isTalking: Bool`
    - `func toggleArmed()`
    - `func shortcutPreferenceChanged()`
    - `func restoreOnQuit()`

This is the integration/glue layer — kept thin and **not unit tested**, mirroring how
`ProTransitionManager` (vs. the tested `ProTransitionManagerTestable`) is the untested AppKit glue
for that subsystem. Its only logic is "look up the transition, execute the named side effect,
refresh the UI" — everything decision-worthy already lives in Task 1's pure state machine.

- [ ] **Step 1: Write the implementation**

Create `src/push-to-talk/PushToTalkController.swift`:

```swift
import CoreAudio

/// AppKit/CoreAudio glue for push-to-talk. Owns the CoreAudio wrapper, the global hotkey
/// registration, and drives the menu bar item + HUD. All *decisions* (what state to go to, what
/// side effect to run) come from `PushToTalkControllerTestable`; this class only executes them.
class PushToTalkController {
    static let shared = PushToTalkController()

    private let audioDevice: PushToTalkAudioDeviceProtocol
    private var state: PushToTalkControllerTestable.State = .disarmed
    private var originalDeviceID: AudioDeviceID?
    private var originalWasMuted: Bool?
    private var originalVolume: Float32?
    private var currentDeviceUsesVolumeFallback = false

    var isArmed: Bool { state != .disarmed }
    var isTalking: Bool { state == .armedTalking }

    init(audioDevice: PushToTalkAudioDeviceProtocol = PushToTalkAudioDevice()) {
        self.audioDevice = audioDevice
        self.audioDevice.observeDefaultInputDeviceChanges { [weak self] in
            self?.handle(.defaultDeviceChanged)
        }
    }

    func toggleArmed() {
        handle(isArmed ? .disarm : .arm)
    }

    /// Re-registers the global hotkey from the current `pushToTalkShortcut` preference. Call once
    /// at startup (from `PreferencesEvents.initialize()`) and again whenever the preference changes.
    func shortcutPreferenceChanged() {
        guard let shortcut = Preferences.pushToTalkShortcut else {
            PushToTalkHotkey.unregister()
            return
        }
        PushToTalkHotkey.register(shortcut, onPress: { [weak self] in self?.handle(.keyDown) },
            onRelease: { [weak self] in self?.handle(.keyUp) })
    }

    /// Best-effort restore on normal quit. Cannot cover SIGKILL/a hard crash — see the spec's
    /// "Failure handling" section.
    func restoreOnQuit() {
        if state != .disarmed {
            handle(.disarm)
        }
    }

    private func handle(_ event: PushToTalkControllerTestable.Event) {
        let transition = PushToTalkControllerTestable.transition(state, event)
        state = transition.nextState
        perform(transition.sideEffect)
        Menubar.refreshPushToTalkMenuItem(isArmed: isArmed, isTalking: isTalking)
        PushToTalkHUD.setVisible(isTalking)
    }

    private func perform(_ sideEffect: PushToTalkControllerTestable.SideEffect) {
        switch sideEffect {
        case .captureAndMute: captureThenMute()
        case .restoreOriginal: restoreOriginal()
        case .unmute: applyTalkPolicy(muted: false)
        case .reMute: applyTalkPolicy(muted: true)
        case .reMuteThenRestore:
            applyTalkPolicy(muted: true)
            restoreOriginal()
        case .reapplyCurrentPolicy: reapplyCurrentPolicyToNewDevice()
        case .none: break
        }
    }

    private func captureThenMute() {
        guard let deviceID = audioDevice.defaultInputDeviceID() else { return }
        originalDeviceID = deviceID
        if audioDevice.isMuteSupported(deviceID) {
            currentDeviceUsesVolumeFallback = false
            originalWasMuted = audioDevice.getMute(deviceID)
            audioDevice.setMute(deviceID, true)
        } else {
            currentDeviceUsesVolumeFallback = true
            originalVolume = audioDevice.getVolume(deviceID)
            audioDevice.setVolume(deviceID, 0)
        }
    }

    private func applyTalkPolicy(muted: Bool) {
        guard let deviceID = originalDeviceID else { return }
        if currentDeviceUsesVolumeFallback {
            audioDevice.setVolume(deviceID, muted ? 0 : (originalVolume ?? 1))
        } else {
            audioDevice.setMute(deviceID, muted)
        }
    }

    private func restoreOriginal() {
        guard let deviceID = originalDeviceID else { return }
        if currentDeviceUsesVolumeFallback {
            audioDevice.setVolume(deviceID, originalVolume ?? 1)
        } else {
            audioDevice.setMute(deviceID, originalWasMuted ?? false)
        }
        originalDeviceID = nil
        originalWasMuted = nil
        originalVolume = nil
        currentDeviceUsesVolumeFallback = false
    }

    /// The default device changed while armed: drop the stale snapshot, re-snapshot + re-mute the
    /// new device, then re-apply the talking sub-state if we were mid-talk.
    private func reapplyCurrentPolicyToNewDevice() {
        restoreOriginal()
        captureThenMute()
        if state == .armedTalking {
            applyTalkPolicy(muted: false)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

This task will not compile standalone until Task 5's `PushToTalkHUD.setVisible(_:)`, Task 6's
`Menubar.refreshPushToTalkMenuItem(isArmed:isTalking:)`, and Task 7's `Preferences.pushToTalkShortcut`
exist. Execute Tasks 5, 6, and 7 before running `bash ai/build.sh` for this task, or land them first
if executing out of order. Once all exist, run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Register the new file in the Xcode project and commit**

```bash
git add src/push-to-talk/PushToTalkController.swift alt-tab-macos.xcodeproj/project.pbxproj
git commit -m "feat: add push-to-talk controller"
```

---

### Task 5: `PushToTalkHUD` — on-screen talking indicator

**Files:**
- Create: `src/push-to-talk/PushToTalkHUD.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure AppKit).
- Produces (consumed by Task 4): `class PushToTalkHUD` with `static func setVisible(_ visible: Bool)`.

Pure visual overlay, not unit tested (matches the rest of the codebase's on-screen panels, e.g.
`TilesPanel`, which also has no direct unit tests — verified visually per the manual QA in Task 8).

- [ ] **Step 1: Write the implementation**

Create `src/push-to-talk/PushToTalkHUD.swift`:

```swift
import Cocoa

/// Borderless, non-activating overlay shown only while push-to-talk is actively talking.
/// Modeled visually on macOS's native volume/brightness HUD: centered near the bottom of the
/// main screen, auto-hidden the instant talking stops.
class PushToTalkHUD {
    private static var panel: NSPanel?
    private static let width: CGFloat = 160
    private static let height: CGFloat = 56

    static func setVisible(_ visible: Bool) {
        visible ? show() : hide()
    }

    private static func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + 80
        let newPanel = NSPanel(contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        newPanel.level = .statusBar
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.ignoresMouseEvents = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        newPanel.contentView = makeContentView()
        newPanel.orderFrontRegardless()
        panel = newPanel
    }

    private static func makeContentView() -> NSView {
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true
        let icon = NSImageView(frame: NSRect(x: (width - 24) / 2, y: 22, width: 24, height: 24))
        icon.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .systemRed
        let label = NSTextField(labelWithString: NSLocalizedString("Talking…", comment: "Push-to-talk on-screen indicator"))
        label.frame = NSRect(x: 0, y: 4, width: width, height: 16)
        label.alignment = .center
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .labelColor
        background.addSubview(icon)
        background.addSubview(label)
        return background
    }

    private static func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Register the new file in the Xcode project and commit**

```bash
git add src/push-to-talk/PushToTalkHUD.swift alt-tab-macos.xcodeproj/project.pbxproj
git commit -m "feat: add on-screen HUD for push-to-talk"
```

---

### Task 6: Menu bar item — arm/disarm toggle + icon state

**Files:**
- Modify: `src/Menubar.swift`
- Modify: `src/App.swift`

**Interfaces:**
- Consumes: `PushToTalkController.shared.toggleArmed()` (Task 4).
- Produces (consumed by Task 4): `Menubar.refreshPushToTalkMenuItem(isArmed: Bool, isTalking: Bool)`.

- [ ] **Step 1: Add the menu item**

In `src/Menubar.swift`, add a stored property near the other menu item properties (next to
`private static var upgradeToProMenuItem: NSMenuItem!`):

```swift
    private static var pushToTalkMenuItem: NSMenuItem!
```

In `initialize()`, add the item right after the "Check permissions…" line and before its trailing
`menu.addItem(NSMenuItem.separator())`:

```swift
        addMenuItem(NSLocalizedString("Check permissions…", comment: "Menubar option"), #selector(App.checkPermissions), "", "hand.raised", nil, App.self)
        pushToTalkMenuItem = addMenuItem(NSLocalizedString("Push-to-talk: Off", comment: "Menubar option"), #selector(App.togglePushToTalkArmed), "", "mic.slash", nil, App.self)
        menu.addItem(NSMenuItem.separator())
```

Add the refresh method (anywhere in the class body, e.g. right after `addMenuItem`):

```swift
    static func refreshPushToTalkMenuItem(isArmed: Bool, isTalking: Bool) {
        guard let pushToTalkMenuItem else { return }
        pushToTalkMenuItem.title = isArmed
            ? NSLocalizedString("Push-to-talk: On", comment: "Menubar option")
            : NSLocalizedString("Push-to-talk: Off", comment: "Menubar option")
        guard #available(macOS 26.0, *) else { return }
        let symbolName = isTalking ? "mic.fill" : (isArmed ? "mic" : "mic.slash")
        pushToTalkMenuItem.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        if isTalking {
            pushToTalkMenuItem.image = pushToTalkMenuItem.image?.withSymbolConfiguration(.init(paletteColors: [.systemRed]))
        }
    }
```

- [ ] **Step 2: Add the App-level selector**

In `src/App.swift`, add next to the other `@objc static func checkPermissions`/`checkForUpdatesNow`
methods:

```swift
    @objc static func togglePushToTalkArmed() {
        PushToTalkController.shared.toggleArmed()
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **` (this task alone does not depend on Task
4/5/7 to compile, since it only references `PushToTalkController.shared` and
`App.togglePushToTalkArmed`, which Task 4/6 already provide once both land — if building this task
in isolation before Task 4 exists, expect an unresolved-identifier error on `PushToTalkController`;
land Task 4 first, or stub-build after all of Tasks 4-7 are in place).

- [ ] **Step 4: Commit**

```bash
git add src/Menubar.swift src/App.swift
git commit -m "feat: add push-to-talk menu bar toggle"
```

---

### Task 7: Preferences — `pushToTalkShortcut` registration + Settings UI row

**Files:**
- Modify: `src/preferences/Preferences.swift`
- Modify: `src/preferences/PreferencesEvents.swift`
- Modify: `src/preferences/settings-window/tabs/GeneralTab.swift`

**Interfaces:**
- Consumes: `PushToTalkController.shared.shortcutPreferenceChanged()` (Task 4).
- Produces (consumed by Task 4): `static var Preferences.pushToTalkShortcut: Shortcut?`.

- [ ] **Step 1: Register the default value**

In `src/preferences/Preferences.swift`, add to `defaultValues`, right after the `"searchShortcut"`
entry:

```swift
            "searchShortcut": defaultShortcut("S"),
            "pushToTalkShortcut": defaultShortcut(""), // no default binding: user must opt in
```

- [ ] **Step 2: Add the accessor**

In the same file, right after the existing `static var searchShortcut: Shortcut? { ... }` accessor:

```swift
    static var pushToTalkShortcut: Shortcut? { CachedUserDefaults.shortcut("pushToTalkShortcut") }
```

- [ ] **Step 3: Wire the preference-changed dispatch**

In `src/preferences/PreferencesEvents.swift`, add a case to the `switch key` block inside
`preferenceChanged(_:)`:

```swift
        case "menubarIcon", "menubarIconShown": applyMenubarPreferencesIfReady()
        case "pushToTalkShortcut": PushToTalkController.shared.shortcutPreferenceChanged()
```

Also call it once at startup, inside `initialize()`, right after `ControlsTab.initializePreferencesDependentState()`:

```swift
        ControlsTab.initializePreferencesDependentState()
        PushToTalkController.shared.shortcutPreferenceChanged()
```

- [ ] **Step 4: Add the Settings UI row**

In `src/preferences/settings-window/tabs/GeneralTab.swift`, add a stored property alongside the
other tab-level dropdown/toggle properties:

```swift
    static var pushToTalkRecorder: CustomRecorderControl?
```

Inside `initTab()`, build the row (this uses `LabelAndControl.setupControl` directly — **not**
`LabelAndControl.makeLabelWithRecorder`, because that helper always routes changes through
`ControlsTab.shortcutChangedCallback`, which assumes the switcher's shortcut registry and would
mis-register this shortcut as `.local` scope):

```swift
        pushToTalkRecorder = CustomRecorderControl(Preferences.pushToTalkShortcut, true, "pushToTalkShortcut")
        _ = LabelAndControl.setupControl(pushToTalkRecorder!, "pushToTalkShortcut", extraAction: { _ in
            PushToTalkController.shared.shortcutPreferenceChanged()
        })
        let pushToTalk = TableGroupView.Row(leftTitle: NSLocalizedString("Push-to-talk shortcut", comment: ""),
            subTitle: NSLocalizedString("Hold this shortcut to unmute your microphone. Arm/disarm push-to-talk from the menu bar.", comment: ""),
            rightViews: [pushToTalkRecorder!])
```

Add it to the table, in its own group, after the existing `table.addNewTable()` sections (right
before the final `return table.submit()`-style return statement — check the end of `initTab()` for
the exact return call and add the row just before it):

```swift
        table.addNewTable()
        table.addRow(pushToTalk)
```

- [ ] **Step 5: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manually verify the Settings row**

Run: `bash ai/run.sh`, open Settings → General, confirm a "Push-to-talk shortcut" row appears with
an empty (unset) recorder, type a shortcut into it, quit and relaunch, confirm it's still set.

- [ ] **Step 7: Commit**

```bash
git add src/preferences/Preferences.swift src/preferences/PreferencesEvents.swift src/preferences/settings-window/tabs/GeneralTab.swift
git commit -m "feat: add push-to-talk shortcut preference and settings row"
```

---

### Task 8: App lifecycle wiring + manual QA

**Files:**
- Modify: `src/App.swift`

**Interfaces:**
- Consumes: `PushToTalkController.shared.restoreOnQuit()` (Task 4).

- [ ] **Step 1: Wire quit-time restore**

In `src/App.swift`, inside `func applicationWillTerminate(_ notification: Notification)`, add:

```swift
    func applicationWillTerminate(_ notification: Notification) {
        PushToTalkController.shared.restoreOnQuit()
```

(as the first statement in the existing method body, before whatever it already does — restoring
the mic should happen as early as possible during teardown).

- [ ] **Step 2: Build to verify it compiles**

Run: `bash ai/build.sh`. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Full manual QA pass**

Run: `bash ai/run.sh`. With a real or virtual microphone attached:

1. Open Settings → General, set a push-to-talk shortcut (e.g. `⌥⇧M`) not already bound elsewhere.
2. Click the menu bar icon → "Push-to-talk: Off" → confirm it flips to "Push-to-talk: On" and the
   system mic (System Settings → Sound → Input, or any meeting app's mic level meter) goes silent.
3. Hold the configured shortcut in another app (e.g. with Zoom/Meet/TextEdit focused) → confirm the
   HUD appears bottom-center of the screen and the mic becomes live; release → HUD disappears, mic
   goes silent again.
4. Click "Push-to-talk: On" again to disarm → confirm the mic returns to whatever state it was in
   before step 2 (e.g. if it started unmuted, it's unmuted again).
5. While armed, physically unplug/replug (or switch) the default input device in System Settings →
   confirm push-to-talk keeps working against the new default device with no crash or stuck mute.
6. Arm push-to-talk, then quit AltTab (Cmd+Q, not a force-quit) → confirm the mic is restored on
   quit.
7. Relaunch AltTab → confirm push-to-talk starts disarmed (state never persists across relaunch,
   per the spec's safety default), even though the configured shortcut is still remembered.

- [ ] **Step 4: Run the full test suite**

Run: `bash ai/build.sh && bundle exec fastlane test` (or the repo's existing test entry point).
Expected: all tests pass, including the new `PushToTalkControllerTestableTests` from Task 1.

- [ ] **Step 5: Commit**

```bash
git add src/App.swift
git commit -m "feat: restore original mic state on quit for push-to-talk"
```
