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
