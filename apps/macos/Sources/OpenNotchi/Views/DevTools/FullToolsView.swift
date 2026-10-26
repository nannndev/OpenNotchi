import SwiftUI

struct FullToolsView: View {
    @EnvironmentObject private var colorPicker: ColorPickerManager
    @EnvironmentObject private var audioDevice: AudioDeviceManager
    @EnvironmentObject private var vm: NotchViewModel
    @Environment(\.notchAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            // Left Card: Color Eyedropper Studio
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Eyedropper Studio", systemImage: "eyedropper.halffull")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent.highlight)
                    Spacer()
                    Button {
                        colorPicker.sampleColor()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.viewfinder")
                            Text("Pick Screen Color")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                if let current = colorPicker.currentColor {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(current.color)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: current.color.opacity(0.4), radius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.hex)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                            Text(current.rgb)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(current.hsl)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Button("Copy HEX") { colorPicker.copyFormat(current, format: .hex) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("Copy RGB") { colorPicker.copyFormat(current, format: .rgb) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }

                    if !colorPicker.recentColors.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(colorPicker.recentColors) { item in
                                    Button {
                                        colorPicker.copyFormat(item, format: .hex)
                                    } label: {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 16, height: 16)
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy \(item.hex)")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("Click Pick Screen Color to sample any pixel")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))

            // Right Card: Audio & Microphone Hub
            VStack(alignment: .leading, spacing: 8) {
                Label("Audio & Microphone Hub", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent.highlight)

                // Mic Mute Live Button
                Button {
                    audioDevice.toggleInputMute()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: audioDevice.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(audioDevice.isMicMuted ? .white : .green)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(audioDevice.isMicMuted ? Color.red.opacity(0.85) : Color.green.opacity(0.2))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(audioDevice.isMicMuted ? "Microphone Globally Muted" : "Microphone Live & Active")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(audioDevice.isMicMuted ? .red : .primary)
                            Text(audioDevice.defaultInputName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(audioDevice.isMicMuted ? "MUTED" : "LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(audioDevice.isMicMuted ? .red : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(audioDevice.isMicMuted ? Color.red.opacity(0.2) : Color.green.opacity(0.2)))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
                }
                .buttonStyle(.plain)

                // Output and Input Device Selectors
                HStack(alignment: .top, spacing: 8) {
                    // Output Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Sound Output:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 3) {
                                ForEach(audioDevice.outputDevices) { device in
                                    Button {
                                        audioDevice.setOutputDevice(device.id)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: device.icon)
                                                .font(.system(size: 9))
                                                .foregroundStyle(device.isDefaultOutput ? accent.highlight : .secondary)

                                            Text(device.name)
                                                .font(.system(size: 9, weight: device.isDefaultOutput ? .semibold : .regular))
                                                .foregroundStyle(device.isDefaultOutput ? .white : .secondary)
                                                .lineLimit(1)

                                            Spacer(minLength: 2)

                                            if device.isDefaultOutput {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(accent.highlight)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(device.isDefaultOutput ? .white.opacity(0.12) : .white.opacity(0.03)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 72)
                    }
                    .frame(maxWidth: .infinity)

                    // Input Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Microphone:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 3) {
                                ForEach(audioDevice.inputDevices) { device in
                                    Button {
                                        audioDevice.setInputDevice(device.id)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: device.icon)
                                                .font(.system(size: 9))
                                                .foregroundStyle(device.isDefaultInput ? .green : .secondary)

                                            Text(device.name)
                                                .font(.system(size: 9, weight: device.isDefaultInput ? .semibold : .regular))
                                                .foregroundStyle(device.isDefaultInput ? .white : .secondary)
                                                .lineLimit(1)

                                            Spacer(minLength: 2)

                                            if device.isDefaultInput {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(device.isDefaultInput ? Color.green.opacity(0.15) : .white.opacity(0.03)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 72)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Dynamic Island HUD Quick Tester
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dynamic Island HUD Tester")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.volume(level: 0.72, muted: false))
                            }
                        } label: {
                            Label("Volume", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.volume(level: 0, muted: true))
                            }
                        } label: {
                            Label("Mute", systemImage: "speaker.slash.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.red.opacity(0.2)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.brightness(level: 0.8))
                            }
                        } label: {
                            Label("Sun", systemImage: "sun.max.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.yellow.opacity(0.2)))
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.device(
                                    name: "AirPods Pro",
                                    symbol: "airpodspro",
                                    battery: 92,
                                    info: DeviceBatteryInfo(left: 92, right: 92, caseBattery: 85, single: 92)
                                ))
                            }
                        } label: {
                            Label("AirPods 🎧", systemImage: "airpodspro")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.green.opacity(0.2)))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
        }
    }
}
