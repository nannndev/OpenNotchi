import AudioToolbox
import CoreAudio

/// Output volume and mute of the default audio device.
enum SystemAudio {
    private static var device: AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }

    /// 0...1, or nil if the device has no adjustable volume (e.g. HDMI).
    static var volume: Float? {
        get {
            guard let device else { return nil }
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr ? value : nil
        }
        set {
            guard let device, var value = newValue.map({ Float32(min(max($0, 0), 1)) }) else { return }
            var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        }
    }

    static var isMuted: Bool {
        get {
            guard let device else { return false }
            var value = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            var addr = address(kAudioDevicePropertyMute)
            return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr && value != 0
        }
        set {
            guard let device else { return }
            var value = UInt32(newValue ? 1 : 0)
            var addr = address(kAudioDevicePropertyMute)
            AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        }
    }
}
