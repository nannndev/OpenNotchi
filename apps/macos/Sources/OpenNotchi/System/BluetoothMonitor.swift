import CoreBluetooth
import Foundation
import IOBluetooth

/// Reports Bluetooth devices (AirPods, headphones, keyboards…) as they connect.
final class BluetoothMonitor: NSObject, CBCentralManagerDelegate {
    /// Called on the main thread with the device's name, an SF Symbol, primary battery, and detailed battery info.
    var onConnect: ((String, String, Int?, DeviceBatteryInfo?) -> Void)?

    private var notification: IOBluetoothUserNotification?
    private var permissionRequest: CBCentralManager?
    private var wantsToRun = false
    private var startedAt = Date()

    func start() {
        wantsToRun = true
        switch CBManager.authorization {
        case .allowedAlways:
            register()
        case .notDetermined:
            // IOBluetooth blocks the main thread while the permission prompt is up,
            // so ask through CoreBluetooth (asynchronous) first.
            permissionRequest = CBCentralManager(delegate: self, queue: .main)
        default:
            break // Denied or restricted: stay quiet.
        }
    }

    func stop() {
        wantsToRun = false
        notification?.unregister()
        notification = nil
    }

    private func register() {
        guard notification == nil, wantsToRun else { return }
        startedAt = Date()
        notification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard CBManager.authorization != .notDetermined else { return }
        permissionRequest = nil
        if CBManager.authorization == .allowedAlways { register() }
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registering also reports devices that were already connected; skip those.
        guard Date().timeIntervalSince(startedAt) > 3 else { return }
        let name = device.name ?? "Bluetooth device"
        let symbol = Self.symbol(for: device, name: name)

        // Battery levels arrive a moment after the connection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            let info = Self.batteryInfo(of: device)
            self?.onConnect?(name, symbol, info.primaryBattery, info)
        }
    }

    private static func symbol(for device: IOBluetoothDevice, name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        switch Int(device.deviceClassMajor) {
        case kBluetoothDeviceClassMajorAudio: return "headphones"
        case kBluetoothDeviceClassMajorPeripheral:
            if lower.contains("mouse") { return "magicmouse.fill" }
            if lower.contains("trackpad") { return "rectangle.and.hand.point.up.left.fill" }
            return "keyboard.fill"
        case kBluetoothDeviceClassMajorPhone: return "iphone"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    /// Battery info via IOBluetoothDevice's undocumented battery properties.
    static func batteryInfo(of device: IOBluetoothDevice) -> DeviceBatteryInfo {
        func read(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)),
                  let value = device.value(forKey: key) as? Int, value > 0 else { return nil }
            return value
        }

        let left = read("batteryPercentLeft")
        let right = read("batteryPercentRight")
        let caseBattery = read("batteryPercentCase")
        let single = read("batteryPercentSingle") ?? read("batteryPercentCombined")

        return DeviceBatteryInfo(left: left, right: right, caseBattery: caseBattery, single: single)
    }

    /// Battery percentage via IOBluetoothDevice's undocumented battery properties.
    private static func battery(of device: IOBluetoothDevice) -> Int? {
        batteryInfo(of: device).primaryBattery
    }
}

