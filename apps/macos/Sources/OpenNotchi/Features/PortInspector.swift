import AppKit
import Foundation

struct ListeningPort: Identifiable, Hashable {
    var id: String { "\(pid):\(port)" }
    let command: String
    let pid: Int32
    let user: String
    let address: String
    let port: Int
    let isLocalhost: Bool

    var url: URL? {
        URL(string: "http://localhost:\(port)")
    }

    var isDevServer: Bool {
        let lower = command.lowercased()
        if lower.contains("controlcenter") || lower.contains("rapportd") || lower.contains("airportd") {
            return false
        }
        let commonDevPorts: Set<Int> = [
            3000, 3001, 3002, 3003, 3333, 4000, 4200, 5000, 5173, 5174, 5500,
            8000, 8080, 8081, 8888, 9000, 9090, 1313, 20128
        ]
        let devKeywords = ["node", "bun", "deno", "python", "python3", "ruby", "go", "cargo", "java", "php", "vite", "next", "webpack", "flask", "django", "rails"]
        if commonDevPorts.contains(port) { return true }
        if devKeywords.contains(where: { lower.contains($0) }) { return true }
        return false
    }

    var icon: String {
        let lower = command.lowercased()
        if lower.contains("node") || lower.contains("next") || lower.contains("vite") {
            return "network"
        } else if lower.contains("python") {
            return "chevron.left.forwardslash.chevron.right"
        } else if lower.contains("go") || lower.contains("cargo") {
            return "shippingbox.fill"
        } else if lower.contains("java") {
            return "cup.and.saucer.fill"
        } else {
            return "globe"
        }
    }
}

final class PortInspector: ObservableObject {
    static let shared = PortInspector()

    @Published private(set) var ports: [ListeningPort] = []
    @Published private(set) var isLoading: Bool = false
    @Published var filterDevOnly: Bool = false
    @Published var searchQuery: String = ""
    @Published var statusMessage: String?

    private var autoRefreshTimer: Timer?
    private var statusTimer: Timer?

    init() {
        refresh()
    }

    var filteredPorts: [ListeningPort] {
        ports.filter { item in
            if filterDevOnly && !item.isDevServer { return false }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let matchesPort = String(item.port).contains(q)
                let matchesCmd = item.command.lowercased().contains(q)
                let matchesPID = String(item.pid).contains(q)
                return matchesPort || matchesCmd || matchesPID
            }
            return true
        }
    }

    func startAutoRefresh() {
        refresh()
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = self?.scanListeningPorts() ?? []
            DispatchQueue.main.async {
                self?.ports = parsed
                self?.isLoading = false
            }
        }
    }

    func openPort(_ port: ListeningPort) {
        if let url = port.url {
            NSWorkspace.shared.open(url)
            showStatus("Opened http://localhost:\(port.port)")
        }
    }

    func killPortProcess(_ port: ListeningPort) {
        let pid = port.pid
        kill(pid, SIGTERM)

        // Optimistically remove from list immediately
        DispatchQueue.main.async {
            self.ports.removeAll { $0.pid == pid }
            self.showStatus("Killed PID \(pid) (:\(port.port))")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [weak self] in
            // Fallback SIGKILL if process didn't terminate
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
            self?.refresh()
        }
    }

    func showStatus(_ message: String) {
        statusMessage = message
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.statusMessage = nil
        }
    }

    private func scanListeningPorts() -> [ListeningPort] {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var results: [ListeningPort] = []
            var seen = Set<String>()

            let lines = output.components(separatedBy: .newlines)
            for line in lines.dropFirst() {
                let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                guard parts.count >= 9 else { continue }

                let command = parts[0]
                guard let pid = Int32(parts[1]) else { continue }
                let user = parts[2]
                let name = parts[8]

                guard let lastColon = name.lastIndex(of: ":") else { continue }
                let portStr = String(name[name.index(after: lastColon)...])
                guard let port = Int(portStr) else { continue }

                let address = String(name[..<lastColon])
                let key = "\(pid):\(port)"
                if seen.contains(key) { continue }
                seen.insert(key)

                let isLocal = address.contains("127.0.0.1") || address.contains("localhost") || address == "*" || address == "[::1]" || address == "[*]"

                results.append(ListeningPort(
                    command: command,
                    pid: pid,
                    user: user,
                    address: address,
                    port: port,
                    isLocalhost: isLocal
                ))
            }

            return results.sorted { a, b in
                if a.isDevServer != b.isDevServer {
                    return a.isDevServer && !b.isDevServer
                }
                return a.port < b.port
            }
        } catch {
            return []
        }
    }
}
