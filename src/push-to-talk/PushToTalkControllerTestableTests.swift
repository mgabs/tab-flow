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
