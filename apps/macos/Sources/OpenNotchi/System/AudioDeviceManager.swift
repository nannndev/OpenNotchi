import AudioToolbox
import CoreAudio
import Foundation
import SwiftUI

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let isOutput: Bool
    let isInput: Bool
    let isDefaultOutput: Bool
    let isDefaultInput: Bool

    var icon: String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            return "airpodspro"
        } else if lower.contains("headphone") || lower.contains("headset") || lower.contains("earphones") {
            return "headphones"
        } else if lower.contains("display") || lower.contains("hdmi") || lower.contains("tv") {
            return "display"
        } else if lower.contains("macbook") || lower.contains("speaker") || lower.contains("internal") {
            return "laptopcomputer"
        } else {
            return isOutput ? "hifispeaker.fill" : "mic.fill"
        }
    }
}

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var currentOutputID: AudioDeviceID?
    @Published private(set) var currentInputID: AudioDeviceID?
    @Published private(set) var defaultOutputName: String = "Default Output"
    @Published private(set) var defaultInputName: String = "Default Microphone"
    @Published var isMicMuted: Bool = false

    private var registeredListeners = false

    init() {
        refreshDevices()
        setupListeners()
    }

    deinit {
        // CoreAudio listeners are automatically cleaned up on process exit
    }

    func refreshDevices() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let allIDs = self.queryAllDeviceIDs()
            let defaultOut = self.queryDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
            let defaultIn = self.queryDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)

            self.currentOutputID = defaultOut
            self.currentInputID = defaultIn
            self.defaultOutputName = defaultOut.map { self.queryDeviceName(id: $0) } ?? "Default Output"
            self.defaultInputName = defaultIn.map { self.queryDeviceName(id: $0) } ?? "Default Microphone"

            var outputs: [AudioDevice] = []
            var inputs: [AudioDevice] = []

            for id in allIDs {
                let name = self.queryDeviceName(id: id)
                let isOut = self.isDeviceType(id: id, scope: kAudioDevicePropertyScopeOutput)
                let isIn = self.isDeviceType(id: id, scope: kAudioDevicePropertyScopeInput)

                if isOut {
                    outputs.append(AudioDevice(
                        id: id,
                        name: name,
                        isOutput: true,
                        isInput: false,
                        isDefaultOutput: id == defaultOut,
                        isDefaultInput: false
                    ))
                }
                if isIn {
                    inputs.append(AudioDevice(
                        id: id,
                        name: name,
                        isOutput: false,
                        isInput: true,
                        isDefaultOutput: false,
                        isDefaultInput: id == defaultIn
                    ))
                }
            }

            self.outputDevices = outputs
            self.inputDevices = inputs
            self.updateInputMuteState()
        }
    }

    func setOutputDevice(_ id: AudioDeviceID) {
        var deviceID = id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
        if status == noErr {
            refreshDevices()
        }
    }

    func toggleInputMute() {
        setInputMuted(!isMicMuted)
    }

    func setInputMuted(_ muted: Bool) {
        guard let inID = currentInputID ?? queryDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice) else { return }
        var value: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(inID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        if status == noErr {
            isMicMuted = muted
        } else {
            // Fallback: Adjust input volume to 0 or restore
            setInputVolume(muted ? 0.0 : 0.75, for: inID)
            isMicMuted = muted
        }
    }

    private func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) {
        var vol = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &vol)
    }

    private func updateInputMuteState() {
        guard let inID = currentInputID else {
            isMicMuted = false
            return
        }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(inID, &address, 0, nil, &size, &value) == noErr {
            isMicMuted = value != 0
        }
    }

    private func setupListeners() {
        guard !registeredListeners else { return }
        registeredListeners = true

        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &outAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshDevices()
        }

        var inAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &inAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshDevices()
        }

        var devAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshDevices()
        }
    }

    // MARK: - CoreAudio Helpers

    private func queryAllDeviceIDs() -> [AudioDeviceID] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices
    }

    private func queryDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    private func queryDeviceName(id: AudioDeviceID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        }
        return status == noErr ? (name as String) : "Audio Device"
    }

    private func isDeviceType(id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        return status == noErr && size > 0
    }
}
