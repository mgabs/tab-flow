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
