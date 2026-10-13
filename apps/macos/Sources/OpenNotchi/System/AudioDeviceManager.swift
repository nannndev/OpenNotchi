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
        } else if lower.contains("iphone") {
            return "iphone"
        } else if lower.contains("ipad") {
            return "ipad"
        } else if lower.contains("headphone") || lower.contains("headset") || lower.contains("earphones") {
            return "headphones"
        } else if lower.contains("display") || lower.contains("hdmi") || lower.contains("tv") {
            return "display"
        } else if lower.contains("macbook") || lower.contains("speaker") || lower.contains("internal") {
            return isOutput ? "laptopcomputer" : "mic.fill"
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
    private var cachedInputVolumes: [AudioDeviceID: Float] = [:]
    private var monitoredInputID: AudioDeviceID?
    private var inputMuteListenerBlock: AudioObjectPropertyListenerBlock?
    private var inputVolListenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        refreshDevices()
        setupListeners()
    }

    deinit {
        cleanupMonitoredInputListener()
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
            self.updateInputDeviceListeners(newID: defaultIn)
            self.updateInputMuteState()
        }
    }

    func setOutputDevice(_ id: AudioDeviceID) {
        var deviceID = id
        // 1. Set main sound output
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )

        // 2. Set system alert & UI sound output
        var sysAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &sysAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )

        refreshDevices()
    }

    func setInputDevice(_ id: AudioDeviceID) {
        var deviceID = id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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

        // Attempt direct CoreAudio mute property
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isMuteSettable: DarwinBoolean = false
        _ = AudioObjectIsPropertySettable(inID, &muteAddress, &isMuteSettable)

        if isMuteSettable.boolValue {
            var value: UInt32 = muted ? 1 : 0
            let status = AudioObjectSetPropertyData(inID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            if status == noErr {
                isMicMuted = muted
                return
            }
        }

        // Fallback: Adjust input volume scalar to 0 or restore saved gain
        if muted {
            if let currentVol = getInputVolume(for: inID), currentVol > 0.05 {
                cachedInputVolumes[inID] = currentVol
            }
            setInputVolume(0.0, for: inID)
            isMicMuted = true
        } else {
            let restoreVol = cachedInputVolumes[inID] ?? 0.75
            setInputVolume(restoreVol, for: inID)
            isMicMuted = false
        }
    }

    func getInputVolume(for deviceID: AudioDeviceID) -> Float? {
        var vol = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol) == noErr {
            return vol
        }

        address.mSelector = kAudioDevicePropertyVolumeScalar
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol) == noErr {
            return vol
        }

        address.mElement = 1
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol) == noErr {
            return vol
        }

        return nil
    }

    func setInputVolume(_ volume: Float, for deviceID: AudioDeviceID) {
        var vol = min(max(volume, 0.0), 1.0)
        let size = UInt32(MemoryLayout<Float32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isSettable: DarwinBoolean = false
        _ = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        if isSettable.boolValue {
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
            return
        }

        address.mSelector = kAudioDevicePropertyVolumeScalar
        _ = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        if isSettable.boolValue {
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
            return
        }

        address.mElement = 1
        _ = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        if isSettable.boolValue {
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
        }
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
            return
        }

        // If direct mute property is unavailable, inspect scalar input volume
        if let currentVol = getInputVolume(for: inID) {
            isMicMuted = currentVol < 0.01
        }
    }

    private func updateInputDeviceListeners(newID: AudioDeviceID?) {
        guard newID != monitoredInputID else { return }
        cleanupMonitoredInputListener()
        monitoredInputID = newID

        guard let targetID = newID else { return }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateInputMuteState() }
        }
        inputMuteListenerBlock = muteBlock
        AudioObjectAddPropertyListenerBlock(targetID, &muteAddr, DispatchQueue.main, muteBlock)

        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateInputMuteState() }
        }
        inputVolListenerBlock = volBlock
        AudioObjectAddPropertyListenerBlock(targetID, &volAddr, DispatchQueue.main, volBlock)
    }

    private func cleanupMonitoredInputListener() {
        guard let oldID = monitoredInputID else { return }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = inputMuteListenerBlock {
            AudioObjectRemovePropertyListenerBlock(oldID, &muteAddr, DispatchQueue.main, block)
            inputMuteListenerBlock = nil
        }

        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = inputVolListenerBlock {
            AudioObjectRemovePropertyListenerBlock(oldID, &volAddr, DispatchQueue.main, block)
            inputVolListenerBlock = nil
        }
        monitoredInputID = nil
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
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        }
        if status == noErr, let name = cfName?.takeRetainedValue() as String? {
            return name
        }
        return "Audio Device"
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
