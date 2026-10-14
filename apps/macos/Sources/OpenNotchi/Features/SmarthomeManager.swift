import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Enums & Models

enum HVACMode: String, CaseIterable, Identifiable, Codable {
    case cool = "cool"
    case eco = "eco"
    case dry = "dry"
    case fan = "fan_only"
    case heat = "heat"
    case off = "off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cool: return "Cool"
        case .eco: return "Eco"
        case .dry: return "Dry"
        case .fan: return "Fan"
        case .heat: return "Heat"
        case .off: return "Off"
        }
    }

    var icon: String {
        switch self {
        case .cool: return "snowflake"
        case .eco: return "leaf.fill"
        case .dry: return "drop.fill"
        case .fan: return "fanblades.fill"
        case .heat: return "flame.fill"
        case .off: return "power"
        }
    }

    var accentColor: Color {
        switch self {
        case .cool: return .cyan
        case .eco: return .green
        case .dry: return .blue
        case .fan: return .teal
        case .heat: return .orange
        case .off: return .secondary
        }
    }
}

enum FanSpeed: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

struct SmartACDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isOn: Bool
    var targetTemperature: Double
    var currentTemperature: Double?
    var mode: HVACMode
    var fanSpeed: FanSpeed
    var minTemp: Double = 16.0
    var maxTemp: Double = 30.0
}

struct SmartLightDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isOn: Bool
    var brightness: Double // 0.0 to 1.0
    var colorTemperature: String? // "warm", "neutral", "cool"
}

struct SmartSwitchDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var isOn: Bool
    var powerWatts: Double?
}

struct SmartScene: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var description: String
}

enum SmarthomeProviderType: String, CaseIterable, Identifiable {
    case demo = "demo"
    case homeAssistant = "homeAssistant"
    case shortcuts = "shortcuts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demo: return "Demo (Simulated)"
        case .homeAssistant: return "Home Assistant"
        case .shortcuts: return "Apple Shortcuts"
        }
    }

    var subtitle: String {
        switch self {
        case .demo: return "Simulated devices to test controls without server setup"
        case .homeAssistant: return "Connect via REST API (http://homeassistant.local:8123)"
        case .shortcuts: return "Trigger native macOS shortcuts for HomeKit devices"
        }
    }
}

// MARK: - Manager

final class SmarthomeManager: ObservableObject {
    static let shared = SmarthomeManager()

    @Published var acDevices: [SmartACDevice] = []
    @Published var lightDevices: [SmartLightDevice] = []
    @Published var switchDevices: [SmartSwitchDevice] = []
    @Published var scenes: [SmartScene] = []

    @Published var selectedACIndex: Int = 0
    @Published var isSyncing = false
    @Published var lastStatusMessage: String?
    @Published var connectionStatus: String = "Ready"

    private let defaults = UserDefaults.standard
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var activeAC: SmartACDevice? {
        guard !acDevices.isEmpty, selectedACIndex < acDevices.count else { return nil }
        return acDevices[selectedACIndex]
    }

    init() {
        loadInitialDevices()
        startPeriodicSync()
    }

    func loadInitialDevices() {
        let settings = AppSettings.shared
        if settings.smarthomeProvider == .homeAssistant, !settings.homeAssistantURL.isEmpty {
            fetchHomeAssistantStates()
        } else {
            loadDemoDevices()
        }
    }

    func loadDemoDevices() {
        acDevices = [
            SmartACDevice(
                id: "climate.bedroom_ac",
                name: "Bedroom AC",
                isOn: true,
                targetTemperature: 22.0,
                currentTemperature: 25.4,
                mode: .cool,
                fanSpeed: .auto
            ),
            SmartACDevice(
                id: "climate.living_room_ac",
                name: "Living Room AC",
                isOn: false,
                targetTemperature: 24.0,
                currentTemperature: 27.1,
                mode: .off,
                fanSpeed: .medium
            )
        ]

        lightDevices = [
            SmartLightDevice(
                id: "light.desk_lamp",
                name: "Desk Lamp",
                isOn: true,
                brightness: 0.85,
                colorTemperature: "warm"
            ),
            SmartLightDevice(
                id: "light.ceiling_ambient",
                name: "Ceiling Ambient",
                isOn: true,
                brightness: 0.50,
                colorTemperature: "neutral"
            ),
            SmartLightDevice(
                id: "light.monitor_lightbar",
                name: "Monitor Bar",
                isOn: false,
                brightness: 0.70,
                colorTemperature: "cool"
            )
        ]

        switchDevices = [
            SmartSwitchDevice(
                id: "switch.standing_fan",
                name: "Standing Fan",
                icon: "fanblades.fill",
                isOn: true,
                powerWatts: 42.5
            ),
            SmartSwitchDevice(
                id: "switch.coffee_maker",
                name: "Coffee Maker",
                icon: "cup.and.saucer.fill",
                isOn: false,
                powerWatts: 0.0
            ),
            SmartSwitchDevice(
                id: "switch.studio_speakers",
                name: "Studio Monitors",
                icon: "speaker.wave.2.fill",
                isOn: true,
                powerWatts: 28.0
            )
        ]

        scenes = [
            SmartScene(id: "scene.focus_work", name: "Focus Work", icon: "sparkles", description: "AC 22°C • Desk 100%"),
            SmartScene(id: "scene.movie_night", name: "Movie Night", icon: "popcorn.fill", description: "AC 21°C • Ambient 20%"),
            SmartScene(id: "scene.sleep_mode", name: "Sleep", icon: "moon.stars.fill", description: "AC 24°C Eco • Lights Off"),
            SmartScene(id: "scene.all_off", name: "All Off", icon: "power", description: "Turn off all devices")
        ]
        connectionStatus = "Simulated Demo"
    }

    // MARK: - AC Controls

    func toggleACPower(id: String) {
        guard let idx = acDevices.firstIndex(where: { $0.id == id }) else { return }
        acDevices[idx].isOn.toggle()
        if acDevices[idx].isOn && acDevices[idx].mode == .off {
            acDevices[idx].mode = .cool
        } else if !acDevices[idx].isOn {
            acDevices[idx].mode = .off
        }
        triggerHaptic()
        notifyPeek(symbol: "air.conditioner.horizontal.fill", text: "\(acDevices[idx].name): \(acDevices[idx].isOn ? "ON (\(Int(acDevices[idx].targetTemperature))°C)" : "OFF")")

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "climate", service: acDevices[idx].isOn ? "turn_on" : "turn_off", entityId: id)
        }
    }

    func setACTemperature(id: String, temperature: Double) {
        guard let idx = acDevices.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(temperature, acDevices[idx].minTemp), acDevices[idx].maxTemp)
        acDevices[idx].targetTemperature = clamped
        triggerHaptic()
        notifyPeek(symbol: "snowflake", text: "\(acDevices[idx].name): \(Int(clamped))°C")

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "climate", service: "set_temperature", entityId: id, data: ["temperature": clamped])
        }
    }

    func stepACTemperature(id: String, delta: Double) {
        guard let ac = acDevices.first(where: { $0.id == id }) else { return }
        setACTemperature(id: id, temperature: ac.targetTemperature + delta)
    }

    func setACMode(id: String, mode: HVACMode) {
        guard let idx = acDevices.firstIndex(where: { $0.id == id }) else { return }
        acDevices[idx].mode = mode
        acDevices[idx].isOn = (mode != .off)
        triggerHaptic()
        notifyPeek(symbol: mode.icon, text: "\(acDevices[idx].name): \(mode.displayName)")

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "climate", service: "set_hvac_mode", entityId: id, data: ["hvac_mode": mode.rawValue])
        }
    }

    func setACFanSpeed(id: String, speed: FanSpeed) {
        guard let idx = acDevices.firstIndex(where: { $0.id == id }) else { return }
        acDevices[idx].fanSpeed = speed
        triggerHaptic()

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "climate", service: "set_fan_mode", entityId: id, data: ["fan_mode": speed.rawValue])
        }
    }

    // MARK: - Light Controls

    func toggleLight(id: String) {
        guard let idx = lightDevices.firstIndex(where: { $0.id == id }) else { return }
        lightDevices[idx].isOn.toggle()
        triggerHaptic()
        notifyPeek(symbol: "lightbulb.fill", text: "\(lightDevices[idx].name): \(lightDevices[idx].isOn ? "ON" : "OFF")")

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "light", service: lightDevices[idx].isOn ? "turn_on" : "turn_off", entityId: id)
        }
    }

    func setLightBrightness(id: String, brightness: Double) {
        guard let idx = lightDevices.firstIndex(where: { $0.id == id }) else { return }
        let clamped = min(max(brightness, 0.0), 1.0)
        lightDevices[idx].brightness = clamped
        lightDevices[idx].isOn = (clamped > 0.01)

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            let haBrightness = Int(clamped * 255)
            callHAService(domain: "light", service: "turn_on", entityId: id, data: ["brightness": haBrightness])
        }
    }

    // MARK: - Switch Controls

    func toggleSwitch(id: String) {
        guard let idx = switchDevices.firstIndex(where: { $0.id == id }) else { return }
        switchDevices[idx].isOn.toggle()
        triggerHaptic()
        notifyPeek(symbol: switchDevices[idx].icon, text: "\(switchDevices[idx].name): \(switchDevices[idx].isOn ? "ON" : "OFF")")

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "switch", service: "toggle", entityId: id)
        }
    }

    // MARK: - Scenes

    func activateScene(_ scene: SmartScene) {
        triggerHaptic()
        notifyPeek(symbol: scene.icon, text: "\(scene.name) Activated")

        switch scene.id {
        case "scene.focus_work":
            if !acDevices.isEmpty {
                acDevices[0].isOn = true
                acDevices[0].targetTemperature = 22.0
                acDevices[0].mode = .cool
            }
            if !lightDevices.isEmpty {
                lightDevices[0].isOn = true
                lightDevices[0].brightness = 1.0
            }
            if !switchDevices.isEmpty { switchDevices[0].isOn = true }
        case "scene.movie_night":
            if !acDevices.isEmpty {
                acDevices[0].isOn = true
                acDevices[0].targetTemperature = 21.0
                acDevices[0].mode = .cool
            }
            for i in lightDevices.indices {
                lightDevices[i].isOn = true
                lightDevices[i].brightness = 0.20
            }
        case "scene.sleep_mode":
            if !acDevices.isEmpty {
                acDevices[0].isOn = true
                acDevices[0].targetTemperature = 24.0
                acDevices[0].mode = .eco
            }
            for i in lightDevices.indices { lightDevices[i].isOn = false }
            for i in switchDevices.indices { switchDevices[i].isOn = false }
        case "scene.all_off":
            for i in acDevices.indices {
                acDevices[i].isOn = false
                acDevices[i].mode = .off
            }
            for i in lightDevices.indices { lightDevices[i].isOn = false }
            for i in switchDevices.indices { switchDevices[i].isOn = false }
        default: break
        }

        if AppSettings.shared.smarthomeProvider == .homeAssistant {
            callHAService(domain: "scene", service: "turn_on", entityId: scene.id)
        } else if AppSettings.shared.smarthomeProvider == .shortcuts {
            runShortcuts(name: scene.name)
        }
    }

    // MARK: - Home Assistant REST API

    func fetchHomeAssistantStates() {
        let settings = AppSettings.shared
        guard let url = URL(string: "\(settings.homeAssistantURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/states") else {
            connectionStatus = "Invalid URL"
            return
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(settings.homeAssistantToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        isSyncing = true
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSyncing = false
                guard let data, error == nil else {
                    self?.connectionStatus = "Connection Failed"
                    return
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                        self?.connectionStatus = "Parse Error"
                        return
                    }
                    self?.parseHomeAssistantEntities(json)
                    self?.connectionStatus = "Connected"
                } catch {
                    self?.connectionStatus = "Error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func parseHomeAssistantEntities(_ list: [[String: Any]]) {
        var newACs: [SmartACDevice] = []
        var newLights: [SmartLightDevice] = []
        var newSwitches: [SmartSwitchDevice] = []
        var newScenes: [SmartScene] = []

        for item in list {
            guard let entityId = item["entity_id"] as? String,
                  let state = item["state"] as? String else { continue }
            let attrs = item["attributes"] as? [String: Any] ?? [:]
            let friendlyName = attrs["friendly_name"] as? String ?? entityId

            if entityId.hasPrefix("climate.") {
                let targetTemp = attrs["temperature"] as? Double ?? 24.0
                let currentTemp = attrs["current_temperature"] as? Double
                let mode = HVACMode(rawValue: state) ?? .off
                let fanMode = FanSpeed(rawValue: attrs["fan_mode"] as? String ?? "") ?? .auto
                let minT = attrs["min_temp"] as? Double ?? 16.0
                let maxT = attrs["max_temp"] as? Double ?? 30.0

                newACs.append(SmartACDevice(
                    id: entityId,
                    name: friendlyName,
                    isOn: (state != "off"),
                    targetTemperature: targetTemp,
                    currentTemperature: currentTemp,
                    mode: mode,
                    fanSpeed: fanMode,
                    minTemp: minT,
                    maxTemp: maxT
                ))
            } else if entityId.hasPrefix("light.") {
                let brightness = (attrs["brightness"] as? Double ?? 255.0) / 255.0
                newLights.append(SmartLightDevice(
                    id: entityId,
                    name: friendlyName,
                    isOn: (state == "on"),
                    brightness: brightness,
                    colorTemperature: "neutral"
                ))
            } else if entityId.hasPrefix("switch.") {
                let power = attrs["current_power_w"] as? Double ?? attrs["power"] as? Double
                newSwitches.append(SmartSwitchDevice(
                    id: entityId,
                    name: friendlyName,
                    icon: "powerplug.fill",
                    isOn: (state == "on"),
                    powerWatts: power
                ))
            } else if entityId.hasPrefix("scene.") {
                newScenes.append(SmartScene(
                    id: entityId,
                    name: friendlyName,
                    icon: "sparkles",
                    description: "Home Assistant Scene"
                ))
            }
        }

        if !newACs.isEmpty { self.acDevices = newACs }
        if !newLights.isEmpty { self.lightDevices = newLights }
        if !newSwitches.isEmpty { self.switchDevices = newSwitches }
        if !newScenes.isEmpty { self.scenes = newScenes }
    }

    private func callHAService(domain: String, service: String, entityId: String, data: [String: Any] = [:]) {
        let settings = AppSettings.shared
        guard let url = URL(string: "\(settings.homeAssistantURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/services/\(domain)/\(service)") else { return }

        var body: [String: Any] = ["entity_id": entityId]
        for (k, v) in data { body[k] = v }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(settings.homeAssistantToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }

    private func runShortcuts(name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            try? process.run()
        }
    }

    // MARK: - Helpers

    private func triggerHaptic() {
        if AppSettings.shared.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func notifyPeek(symbol: String, text: String) {
        AppDelegate.shared?.screenManager.showPeek(.device(
            name: text,
            symbol: symbol,
            battery: nil
        ))
    }

    private func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            if AppSettings.shared.smarthomeProvider == .homeAssistant {
                self?.fetchHomeAssistantStates()
            }
        }
    }
}
