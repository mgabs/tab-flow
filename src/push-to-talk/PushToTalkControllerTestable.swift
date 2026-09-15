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
