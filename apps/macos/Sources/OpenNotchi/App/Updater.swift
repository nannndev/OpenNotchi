import AppKit
import Combine
import Foundation
import Sparkle

struct AppUpdateInfo: Equatable {
    let version: String
    let title: String
    let releaseNotes: String?
    let releaseURL: URL?
}

/// Wraps Sparkle & GitHub Releases to check for updates and present notch notification banners.
final class Updater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    @Published var availableUpdate: AppUpdateInfo? = nil
    @Published var isChecking = false

    var onUpdateBanner: ((Banner) -> Void)?

    let isAvailable: Bool
    private var controller: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?
    private var checkTimer: Timer?

    override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = info["SUFeedURL"] as? String ?? ""
        let key = info["SUPublicEDKey"] as? String ?? ""
        isAvailable = !feed.isEmpty && !key.isEmpty

        automaticallyChecks = true
        super.init()

        if isAvailable {
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
            self.controller = controller
            automaticallyChecks = controller.updater.automaticallyChecksForUpdates
            cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.canCheckForUpdates = $0 }
        } else {
            controller = nil
            canCheckForUpdates = true
        }

        // Check for updates in the background on startup (after 5s) and periodically every 6 hours
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.checkGitHubReleasesSilently()
        }
        checkTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.checkGitHubReleasesSilently()
        }
    }

    func checkForUpdates() {
        if isAvailable, let controller {
            controller.checkForUpdates(nil)
        } else {
            checkGitHubReleases(interactive: true)
        }
    }

    // MARK: - Sparkle Delegate
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        DispatchQueue.main.async { [weak self] in
            self?.handleUpdateFound(
                version: version,
                title: "Update OpenNotchi v\(version) Tersedia",
                notes: item.itemDescription,
                url: nil
            )
        }
    }

    // MARK: - GitHub Releases Check
    func checkGitHubReleases(interactive: Bool = false) {
        isChecking = true
        guard let url = URL(string: "https://api.github.com/repos/nannndev/OpenNotchi/releases/latest") else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("OpenNotchi-MacApp", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                guard let data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    if interactive {
                        self.showNoUpdateAlert()
                    }
                    return
                }

                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let releaseName = json["name"] as? String ?? "OpenNotchi \(tagName)"
                let body = json["body"] as? String
                let htmlUrlString = json["html_url"] as? String ?? "https://github.com/nannndev/OpenNotchi/releases"
                let releaseURL = URL(string: htmlUrlString)

                if self.isVersion(latestVersion, newerThan: currentVersion) {
                    self.handleUpdateFound(
                        version: latestVersion,
                        title: releaseName,
                        notes: body,
                        url: releaseURL
                    )
                } else if interactive {
                    self.showAlreadyLatestAlert(currentVersion: currentVersion)
                }
            }
        }.resume()
    }

    private func checkGitHubReleasesSilently() {
        checkGitHubReleases(interactive: false)
    }

    private func handleUpdateFound(version: String, title: String, notes: String?, url: URL?) {
        let update = AppUpdateInfo(
            version: version,
            title: title,
            releaseNotes: notes,
            releaseURL: url
        )
        self.availableUpdate = update

        // Present Dynamic Island banner drop-down from notch
        let banner = Banner(
            icon: "sparkles",
            tint: .cyan,
            badge: "v\(version)",
            title: "Update Tersedia: v\(version)",
            subtitle: "Versi baru siap dipasang langsung dari notch",
            actionTitle: "Update Sekarang",
            actionURL: url,
            actionType: isAvailable ? .triggerUpdate : .openURL
        )
        onUpdateBanner?(banner)
    }

    /// Simulate update notification banner for testing / demo
    func simulateUpdateNotification(version: String = "0.5.1") {
        handleUpdateFound(
            version: version,
            title: "Update OpenNotchi v\(version) Tersedia",
            notes: "Perbaikan kontrol audio, animasi pembuka notch baru, dan pemutar vinyl interaktif.",
            url: URL(string: "https://github.com/nannndev/OpenNotchi/releases")
        )
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(p1.count, p2.count)
        for i in 0..<maxCount {
            let num1 = i < p1.count ? p1[i] : 0
            let num2 = i < p2.count ? p2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }

    private func showAlreadyLatestAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Versi Terbaru Sudah Terpasang"
        alert.informativeText = "OpenNotchi v\(currentVersion) adalah versi paling mutakhir."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "Tidak Dapat Memeriksa Update"
        alert.informativeText = "Pastikan koneksi internet aktif atau coba beberapa saat lagi."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
