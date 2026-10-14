import SwiftUI

struct SmarthomeView: View {
    @EnvironmentObject private var smarthome: SmarthomeManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            // Left: AC Climate Deck
            climateDeck
                .frame(width: 242)

            // Center: Lighting Studio
            lightingDeck
                .frame(width: 220)

            // Right: Smart Switches & Scenes
            switchesAndScenesDeck
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Climate & AC Deck

    private var climateDeck: some View {
        VStack(spacing: 6) {
            if let ac = smarthome.activeAC {
                // Header: Device title & Power button
                HStack(spacing: 6) {
                    Image(systemName: "air.conditioner.horizontal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ac.isOn ? ac.mode.accentColor : .secondary)

                    Text(ac.name)
                        .font(.system(size: 11.5, weight: .bold))
                        .lineLimit(1)

                    Spacer()

                    if smarthome.acDevices.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                smarthome.selectedACIndex = (smarthome.selectedACIndex + 1) % smarthome.acDevices.count
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // AC Power Button
                    Button {
                        smarthome.toggleACPower(id: ac.id)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ac.isOn ? .white : .secondary)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(ac.isOn ? ac.mode.accentColor.opacity(0.75) : Color.white.opacity(0.08))
                            )
                            .shadow(color: ac.isOn ? ac.mode.accentColor.opacity(0.4) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                }

                // Center Dial / Thermostat
                HStack(spacing: 12) {
                    // Minus Button
                    Button {
                        smarthome.stepACTemperature(id: ac.id, delta: -1.0)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(0.08)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!ac.isOn)
                    .opacity(ac.isOn ? 1 : 0.4)

                    // Target Temp Display
                    VStack(spacing: 0) {
                        Text("\(Int(ac.targetTemperature))°")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(ac.isOn ? .white : .secondary)
                            .shadow(color: ac.isOn ? ac.mode.accentColor.opacity(0.5) : .clear, radius: 8)

                        if let current = ac.currentTemperature {
                            Text("Room \(String(format: "%.1f", current))°C")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 70)

                    // Plus Button
                    Button {
                        smarthome.stepACTemperature(id: ac.id, delta: 1.0)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(0.08)))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!ac.isOn)
                    .opacity(ac.isOn ? 1 : 0.4)
                }
                .padding(.vertical, 2)

                // HVAC Modes Bar
                HStack(spacing: 4) {
                    ForEach([HVACMode.cool, .eco, .dry, .fan], id: \.self) { mode in
                        Button {
                            smarthome.setACMode(id: ac.id, mode: mode)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 8.5))
                                Text(mode.displayName)
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(ac.isOn && ac.mode == mode ? mode.accentColor.opacity(0.3) : .white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ac.isOn && ac.mode == mode ? mode.accentColor.opacity(0.7) : .clear, lineWidth: 0.8)
                            )
                            .foregroundStyle(ac.isOn && ac.mode == mode ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Fan Speed Pills
                HStack(spacing: 4) {
                    Text("FAN")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 2)

                    ForEach(FanSpeed.allCases) { speed in
                        Button {
                            smarthome.setACFanSpeed(id: ac.id, speed: speed)
                        } label: {
                            Text(speed.displayName)
                                .font(.system(size: 8.5, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2.5)
                                .background(
                                    Capsule().fill(ac.fanSpeed == speed ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                )
                                .foregroundStyle(ac.fanSpeed == speed ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "air.conditioner.horizontal")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No AC Detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Lighting Deck

    private var lightingDeck: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Label("Lights", systemImage: "lightbulb.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(smarthome.lightDevices.filter { $0.isOn }.count)/\(smarthome.lightDevices.count) On")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Light items list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(smarthome.lightDevices) { light in
                        lightRow(light)
                    }
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                )
        }
    }

    private func lightRow(_ light: SmartLightDevice) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    smarthome.toggleLight(id: light.id)
                } label: {
                    Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(light.isOn ? .yellow : .secondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(light.isOn ? Color.yellow.opacity(0.25) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Text(light.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text("\(Int(light.brightness * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(light.isOn ? .yellow : .secondary)
            }

            // Custom Compact Brightness Slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    Capsule()
                        .fill(light.isOn ? Color.yellow.gradient : Color.white.opacity(0.2).gradient)
                        .frame(width: max(geo.size.width * CGFloat(light.brightness), 6), height: 5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percent = Double(value.location.x / geo.size.width).clamped(to: 0.0...1.0)
                            smarthome.setLightBrightness(id: light.id, brightness: percent)
                        }
                )
            }
            .frame(height: 8)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(light.isOn ? Color.yellow.opacity(0.05) : Color.white.opacity(0.02))
        )
    }

    // MARK: - Smart Switches & Quick Scenes

    private var switchesAndScenesDeck: some View {
        VStack(spacing: 6) {
            // Switches Header
            HStack {
                Label("Switches", systemImage: "powerplug.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.green)
                Spacer()
            }

            // Smart Plugs Horizontal Row
            HStack(spacing: 6) {
                ForEach(smarthome.switchDevices) { device in
                    Button {
                        smarthome.toggleSwitch(id: device.id)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: device.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(device.isOn ? .green : .secondary)

                            Text(device.name)
                                .font(.system(size: 8.5, weight: .medium))
                                .lineLimit(1)

                            if let watts = device.powerWatts, device.isOn {
                                Text("\(Int(watts))W")
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(device.isOn ? Color.green.opacity(0.14) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(device.isOn ? Color.green.opacity(0.4) : Color.clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 2)

            // Quick Scenes Header
            HStack {
                Text("QUICK SCENES")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Quick Scenes Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(smarthome.scenes) { scene in
                    Button {
                        smarthome.activateScene(scene)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: scene.icon)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.cyan)

                            Text(scene.name)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                )
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
