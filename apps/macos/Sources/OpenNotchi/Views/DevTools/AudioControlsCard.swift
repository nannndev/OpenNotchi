import SwiftUI

struct AudioControlsCard: View {
    @EnvironmentObject private var audioDevice: AudioDeviceManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Audio & Mic Control", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            // Mic Mute Toggle Button
            Button {
                audioDevice.toggleInputMute()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: audioDevice.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(audioDevice.isMicMuted ? .white : .green)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle().fill(audioDevice.isMicMuted ? Color.red.opacity(0.85) : Color.green.opacity(0.18))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(audioDevice.isMicMuted ? "Microphone Muted" : "Microphone Live")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(audioDevice.isMicMuted ? .red : .primary)
                            .lineLimit(1)
                        Text(audioDevice.defaultInputName)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    Image(systemName: audioDevice.isMicMuted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(audioDevice.isMicMuted ? .red : .secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(audioDevice.isMicMuted ? "Click to Unmute Microphone" : "Click to Mute Microphone")

            // Audio Output Device Selector Menu
            Menu {
                ForEach(audioDevice.outputDevices) { device in
                    Button {
                        audioDevice.setOutputDevice(device.id)
                    } label: {
                        HStack {
                            Image(systemName: device.icon)
                            Text(device.name)
                            if device.isDefaultOutput {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: outputDeviceIcon(name: audioDevice.defaultOutputName))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accent.highlight)

                    Text(audioDevice.defaultOutputName)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Switch Audio Output Device")

            // Microphone Input Device Selector Menu
            Menu {
                ForEach(audioDevice.inputDevices) { device in
                    Button {
                        audioDevice.setInputDevice(device.id)
                    } label: {
                        HStack {
                            Image(systemName: device.icon)
                            Text(device.name)
                            if device.isDefaultInput {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: inputDeviceIcon(name: audioDevice.defaultInputName))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(audioDevice.isMicMuted ? .red : .green)

                    Text(audioDevice.defaultInputName)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Switch Microphone Input Device")
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
    }

    private func outputDeviceIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") { return "airpodspro" }
        if lower.contains("headphone") { return "headphones" }
        if lower.contains("display") || lower.contains("hdmi") { return "display" }
        if lower.contains("macbook") || lower.contains("speaker") { return "laptopcomputer" }
        return "hifispeaker.fill"
    }

    private func inputDeviceIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") { return "airpodspro" }
        if lower.contains("iphone") { return "iphone" }
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("headphone") || lower.contains("headset") { return "headphones" }
        return "mic.fill"
    }
}
