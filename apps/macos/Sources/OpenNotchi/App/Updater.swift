import Combine
import Foundation
import Sparkle

/// Wraps Sparkle so SwiftUI can show update controls.
/// Updates are only enabled in builds whose Info.plist has a feed URL and public key.
final class Updater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    let isAvailable: Bool
    private let controller: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = info["SUFeedURL"] as? String ?? ""
        let key = info["SUPublicEDKey"] as? String ?? ""
        isAvailable = !feed.isEmpty && !key.isEmpty

        if isAvailable {
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            self.controller = controller
            automaticallyChecks = controller.updater.automaticallyChecksForUpdates
            cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.canCheckForUpdates = $0 }
        } else {
            controller = nil
            automaticallyChecks = false
        }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
