import SwiftUI

struct SmarthomePane: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var smarthome = SmarthomeManager.shared
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("Smarthome Tab") {
                Toggle("Show Smarthome in Notch Tabs", isOn: $settings.smarthomeEnabled)
            }

            Section("Provider & Integration") {
                Picker("Integration Mode", selection: $settings.smarthomeProvider) {
                    ForEach(SmarthomeProviderType.allCases) { provider in
                        Label(
                            provider.displayName,
                            systemImage: provider == .demo
                                ? "laptopcomputer" : (provider == .homeAssistant ? "house.fill" : "command")
                        ).tag(provider)
                    }
                }
                Text(settings.smarthomeProvider.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.smarthomeProvider == .homeAssistant {
                Section("Home Assistant Configuration") {
                    TextField("Server URL", text: $settings.homeAssistantURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Long-Lived Access Token", text: $settings.homeAssistantToken)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(isTesting || settings.homeAssistantURL.isEmpty)

                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains("Connected") ? .green : .red)
                        }
                    }

                    Text(
                        "Generate a token in Home Assistant: click your profile in the bottom-left → Long-Lived Access Tokens → Create Token."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if settings.smarthomeProvider == .shortcuts {
                Section("Apple Shortcuts Setup") {
                    Text(
                        "Name shortcuts matching scenes or devices: e.g. “Focus Work”, “Movie Night”, “Turn On AC”, “Turn Off Lights”."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section(
                "Active Devices (\(smarthome.acDevices.count + smarthome.lightDevices.count + smarthome.switchDevices.count))"
            ) {
                ForEach(smarthome.acDevices) { ac in
                    HStack {
                        Label(ac.name, systemImage: "air.conditioner.horizontal.fill")
                        Spacer()
                        Text("\(Int(ac.targetTemperature))°C • \(ac.mode.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(smarthome.lightDevices) { light in
                    HStack {
                        Label(light.name, systemImage: "lightbulb.fill")
                        Spacer()
                        Text("\(Int(light.brightness * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(smarthome.switchDevices) { sw in
                    HStack {
                        Label(sw.name, systemImage: sw.icon)
                        Spacer()
                        Text(sw.isOn ? "On" : "Off")
                            .font(.caption)
                            .foregroundStyle(sw.isOn ? .green : .secondary)
                    }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        smarthome.fetchHomeAssistantStates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTesting = false
            testResult = smarthome.connectionStatus
        }
    }
}
