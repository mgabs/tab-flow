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
        // Registered exactly once per instance: `observeDefaultInputDeviceChanges` adds a CoreAudio
        // listener block with no de-duplication, so calling it again would stack duplicates.
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
        // Carbon never delivers `kEventHotKeyReleased` for a hotkey that got unregistered mid-hold,
        // so the old shortcut's key-up has to be synthesized before the old registration goes away,
        // or the state machine stays in `.armedTalking` and the mic stays unmuted indefinitely.
        if isTalking {
            handle(.keyUp)
        }
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
        Menubar.refreshPushToTalkIndicators(isArmed: isArmed, isTalking: isTalking)
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
