# Push-to-talk — design

## Summary

A free, opt-in feature: while armed, AltTab keeps the system's default microphone
input muted; holding a configurable global shortcut temporarily un-mutes it (and
releasing re-mutes it) so the user can speak during meetings. This is unrelated to
window switching — it uses AltTab's existing global-hotkey and menu-bar
infrastructure to ship a standalone system utility.

## Goals

- Hold a key to talk in any meeting app (Zoom, Teams, Meet, FaceTime, ...) without
  that app needing to support push-to-talk itself.
- Muting must be system-wide (CoreAudio default input device), not app-specific —
  simple, robust, and works identically regardless of which app has focus.
- Arming/disarming is an explicit, visible user action; the feature is never
  silently active.
- No feature gating — free for all users.

## Non-goals

- No per-app mute (e.g. simulating Zoom's own mute shortcut). Rejected: fragile,
  app-shortcut-version-dependent, and steals focus.
- No voice commands / speech recognition. This is a mute/unmute switch, nothing
  interprets what's said.
- No persistence of the armed state across app relaunch (see Safety default below).

## User-facing behavior

1. **Preferences**: a new shortcut row, "Push-to-talk shortcut" (reuses the
   existing `ShortcutEditor`/`CustomRecorderControl` UI already used for other
   shortcuts, e.g. `focusWindowShortcut`).
2. **Arm/disarm**: a new menu bar item, "Push-to-talk: Off" / "Push-to-talk: On",
   toggled by click (pattern: `Menubar.addMenuItem`, next to "Check for
   updates…"). Arming immediately mutes the mic; disarming restores it.
3. **Talk**: while armed, holding the configured shortcut un-mutes the mic and
   shows a small on-screen HUD (new; modeled visually on macOS's native
   volume/brightness overlay — center-bottom of the main screen, auto-hides on
   release). Releasing re-mutes and hides the HUD.
4. **Menu bar icon**: the existing status item gains a small badge/tint while
   armed (dim mic glyph) vs. talking (filled/red mic glyph), so state is visible
   without opening the menu.

## Safety default: armed state never persists

The armed/disarmed state is **in-memory only**, not written to `UserDefaults`.
Every launch starts disarmed. Rationale: if armed state persisted and the app
relaunched (crash, update, macOS restart) while armed, the user's mic would come
back silently muted with no visible cause until they went looking for it — a
much worse failure mode than requiring one extra click to re-arm each session.
The configured shortcut itself (`pushToTalkShortcut`) *does* persist, like any
other shortcut preference.

## Architecture

### Components

- **`PushToTalkController`** (new, `src/push-to-talk/`) — owns the state machine
  below, wires the menu bar item, the HUD, and the global shortcut, and is the
  only thing that talks to `PushToTalkAudioDevice`.
- **`PushToTalkControllerTestable`** (new) — pure state-transition function(s),
  following the existing `ProTransitionManagerTestable` split: given a state and
  an event (arm/disarm/talk-start/talk-end/device-changed), returns the next
  state and the side-effects to perform. Fully unit-testable without CoreAudio
  or a real menu bar.
- **`PushToTalkAudioDevice`** (new) — CoreAudio wrapper, isolated behind a small
  protocol (`PushToTalkAudioDeviceProtocol`) so tests can mock it:
  - `defaultInputDeviceID() -> AudioDeviceID?`
  - `mute(_ deviceID:) -> Bool` (returns whether hardware mute was applied)
  - `unmute(_ deviceID:, wasHardwareMuted: Bool)`
  - `observeDefaultDeviceChanges(_ handler:)` (via
    `kAudioHardwarePropertyDefaultInputDevice` listener)
- **`PushToTalkHUD`** (new) — a borderless, non-activating `NSPanel` shown only
  while talking; auto-positioned bottom-center of the active screen, matching
  the visual weight of AltTab's other on-screen surfaces.
- **Preferences**: one new shortcut entry, `pushToTalkShortcut`, registered
  alongside existing shortcuts in `PreferenceDefinition.swift` and surfaced in
  `ControlsTab.swift`.
- **Menu bar**: one new `NSMenuItem` in `Menubar.swift`, plus a small icon-state
  update hook alongside the existing status-item icon logic.

### State machine (`PushToTalkControllerTestable`)

```
disarmed --(arm)--> armed-muted
armed-muted --(disarm)--> disarmed
armed-muted --(key down)--> armed-talking      [unmute]
armed-talking --(key up)--> armed-muted        [re-mute]
armed-talking --(disarm)--> disarmed           [re-mute, then restore]
armed-muted/armed-talking --(default device changed)--> re-detect + re-apply
                                                   current state's mute policy
                                                   to the new device
```

`arm` captures the current default device's original mute/volume state before
muting it, so `disarm` can restore exactly what the user had (including if it
was already muted, or already at some particular volume).

### Mute mechanism

On `arm` (and again on device change while armed):
1. Query the default input device for `kAudioDevicePropertyMute`.
2. If supported: save current mute value, set mute = true.
3. If unsupported: save current `kAudioDevicePropertyVolumeScalar`, set to 0.

On `talk-start`: invert step 2/3 (unmute, or restore saved volume).
On `talk-end`: re-apply step 2/3.
On `disarm`: restore the originally-saved value from step 1 (mute state or
volume), regardless of current sub-state.

### Global shortcut integration

Reuses `KeyboardEvents.addGlobalShortcut`/`removeGlobalShortcut`, which already
provide press *and* release callbacks via Carbon `EventHotKey` (the same
mechanism driving the switcher's existing hold-shortcut). The push-to-talk
shortcut is registered independently of `SwitcherSession` — it is active
whenever armed, regardless of whether the switcher UI is open.

### Failure handling

- **App quits while armed**: `applicationWillTerminate` restores the original
  device state (best-effort; cannot cover `SIGKILL` or a hard crash — documented
  as a known limitation, matching the existing crash-handling posture in
  `src/main.swift`'s `emergencyExit`).
- **Device removed while muted-via-volume**: CoreAudio calls simply no-op/fail
  silently if the device ID is stale; the next default-device-change
  notification re-syncs onto whatever device is now default.
- **Hardware mute reports success but has no audible effect** (seen on some
  devices): out of scope to detect from software; the volume-fallback path is
  the reliable backstop and is what most third-party PTT utilities rely on too.

## Testing

- `PushToTalkControllerTestable`: full state-machine coverage via XCTest — every
  transition in the diagram above, plus the device-changed re-apply behavior,
  using a mock `PushToTalkAudioDeviceProtocol`.
- `PushToTalkController` itself (the AppKit/CoreAudio glue): kept thin,
  integration-only, not unit tested directly — mirrors how `ProTransitionManager`
  vs. `ProTransitionManagerTestable` are split today.
- Manual QA: arm/disarm, talk while armed, unplug/replug an input device while
  armed, quit while armed and confirm mic is restored.

## Open risks (disclosed, not blocking)

- Some meeting apps show their own "muted" indicator based on their own mute
  button state, not actual input silence — while armed-but-not-talking, the
  user's mic is truly silent, but the meeting app's own UI may not reflect that
  (a purely cosmetic mismatch, not a functional one).
- The volume-fallback path changes the OS-reported input volume while armed,
  visible in System Settings' Sound pane — disclosed above as a known,
  accepted trade-off (per earlier decision).
