import AppKit

enum AirDropService {
    static var isAvailable: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    static func send(_ urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else {
            NSSound.beep()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }
}
