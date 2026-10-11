import AppKit
import UniformTypeIdentifiers

/// Files the user parked in the notch. Stores references, not copies.
final class TrayStore: ObservableObject {
    @Published private(set) var items: [URL] = [] {
        didSet { save() }
    }

    private let key = "trayItems"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        items = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func add(_ urls: [URL]) {
        let new = urls.filter { !items.contains($0) }
        guard !new.isEmpty else { return }
        items.append(contentsOf: new)
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
    }

    func clear() {
        items.removeAll()
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.path), forKey: key)
    }

    /// Handles a SwiftUI drop. Returns true if any provider carried a file URL.
    @discardableResult
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        Self.loadFileURLs(from: providers) { [weak self] urls in
            self?.add(urls)
        }
    }

    @discardableResult
    static func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { completion(urls) }
        return true
    }
}
