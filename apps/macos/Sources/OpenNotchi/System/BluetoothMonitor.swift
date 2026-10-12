import CoreBluetooth
import Foundation
import IOBluetooth

/// Reports Bluetooth devices (AirPods, headphones, keyboards…) as they connect.
final class BluetoothMonitor: NSObject, CBCentralManagerDelegate {
    /// Called on the main thread with the device's name, an SF Symbol and battery (if known).
    var onConnect: ((String, String, Int?) -> Void)?

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onConnect?(name, symbol, Self.battery(of: device))
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

    /// Battery percentage via IOBluetoothDevice's undocumented battery properties.
    /// Returns nil when the device doesn't report one.
    private static func battery(of device: IOBluetoothDevice) -> Int? {
        let keys = ["batteryPercentCombined", "batteryPercentSingle", "batteryPercentLeft", "batteryPercentRight"]
        let values = keys.compactMap { key -> Int? in
            guard device.responds(to: NSSelectorFromString(key)),
                  let value = device.value(forKey: key) as? Int, value > 0 else { return nil }
            return value
        }
        return values.first
    }
}
