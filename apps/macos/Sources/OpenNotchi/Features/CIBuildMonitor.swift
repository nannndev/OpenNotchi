import AppKit
import Foundation

struct CIWorkflowRun: Identifiable, Equatable {
    let id: Int
    let repo: String
    let workflowName: String
    let displayTitle: String
    let branch: String
    let status: String       // "completed", "in_progress", "queued", "waiting"
    let conclusion: String?  // "success", "failure", "cancelled", "skipped", nil
    let event: String
    let htmlURL: URL?
    let updatedAt: Date?

    var isRunning: Bool {
        status == "in_progress" || status == "queued" || status == "waiting" || status == "requested"
    }

    var isSuccess: Bool {
        status == "completed" && conclusion == "success"
    }

    var isFailure: Bool {
        status == "completed" && (conclusion == "failure" || conclusion == "timed_out" || conclusion == "startup_failure")
    }

    var statusIcon: String {
        if isRunning { return "arrow.triangle.2.circlepath" }
        switch conclusion {
        case "success": return "checkmark.circle.fill"
        case "failure", "timed_out": return "xmark.octagon.fill"
        case "cancelled": return "slash.circle.fill"
        default: return "clock.fill"
        }
    }

    var statusLabel: String {
        if status == "in_progress" { return "Building" }
        if status == "queued" || status == "waiting" { return "Queued" }
        switch conclusion {
        case "success": return "Passed"
        case "failure": return "Failed"
        case "cancelled": return "Cancelled"
        default: return status.capitalized
        }
    }

    var relativeTime: String {
        guard let updatedAt else { return "" }
        let sec = Int(max(0, Date().timeIntervalSince(updatedAt)))
        if sec < 60 { return "just now" }
        let min = sec / 60
        if min < 60 { return "\(min)m ago" }
        let hr = min / 60
        if hr < 24 { return "\(hr)h ago" }
        return "\(hr / 24)d ago"
    }
}

struct LocalBuildProcess: Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let tool: String
    let commandLine: String
}

/// Polls GitHub Actions runs (via `gh` CLI or GitHub REST API) and local compiler processes,
/// surfacing a closed-notch Live Activity while building and a Banner when a workflow finishes.
final class CIBuildMonitor: ObservableObject {
    static let shared = CIBuildMonitor()

    @Published private(set) var runs: [CIWorkflowRun] = []
    @Published private(set) var localBuilds: [LocalBuildProcess] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published var repositories: [String] {
        didSet {
            UserDefaults.standard.set(repositories, forKey: "ciMonitoredRepos")
        }
    }
    @Published var selectedRepo: String {
        didSet {
            UserDefaults.standard.set(selectedRepo, forKey: "ciSelectedRepo")
            refresh()
        }
    }

    var onBanner: ((Banner) -> Void)?

    private var pollTimer: Timer?
    private var localPollTimer: Timer?
    /// Tracks previous status by run ID so we only fire a banner on transition into "completed".
    private var knownRunStatuses: [Int: String] = [:]
    private var hasCompletedInitialFetch = false

    var activeRuns: [CIWorkflowRun] {
        runs.filter(\.isRunning)
    }

    var hasActiveBuild: Bool {
        !activeRuns.isEmpty || !localBuilds.isEmpty
    }

    var closedActivitySummary: (leftLabel: String, rightLabel: String, isLocal: Bool)? {
        if let local = localBuilds.first {
            return (leftLabel: local.tool, rightLabel: "BUILDING", isLocal: true)
        }
        if let run = activeRuns.first {
            let shortBranch = String(run.branch.prefix(10))
            return (leftLabel: shortBranch.isEmpty ? "CI" : shortBranch, rightLabel: "CI RUN", isLocal: false)
        }
        return nil
    }

    private init() {
        let defaults = UserDefaults.standard
        let savedRepos = defaults.stringArray(forKey: "ciMonitoredRepos") ?? []
        let detected = Self.detectDefaultRepo() ?? "nannndev/OpenNotchi"
        let initialRepos = savedRepos.isEmpty ? [detected] : savedRepos
        self.repositories = initialRepos
        let savedSelected = defaults.string(forKey: "ciSelectedRepo") ?? ""
        self.selectedRepo = initialRepos.contains(savedSelected) ? savedSelected : (initialRepos.first ?? detected)
    }

    func startMonitoring() {
        refresh()
        scanLocalBuilds()

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        localPollTimer?.invalidate()
        localPollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.scanLocalBuilds()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        localPollTimer?.invalidate()
        localPollTimer = nil
    }

    func addRepository(_ rawSlug: String) {
        let cleaned = Self.cleanRepoSlug(rawSlug)
        guard !cleaned.isEmpty, cleaned.contains("/") else { return }
        if !repositories.contains(cleaned) {
            repositories.insert(cleaned, at: 0)
        }
        selectedRepo = cleaned
    }

    func removeRepository(_ slug: String) {
        repositories.removeAll { $0 == slug }
        if selectedRepo == slug {
            selectedRepo = repositories.first ?? "nannndev/OpenNotchi"
        }
    }

    func refresh() {
        let repo = selectedRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repo.isEmpty, !isLoading else { return }
        isLoading = true
        lastError = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let fetchedResult = self.fetchRunsViaGH(repo: repo) ?? self.fetchRunsViaREST(repo: repo)
            DispatchQueue.main.async {
                self.isLoading = false
                switch fetchedResult {
                case .success(let newRuns):
                    self.processRunTransitions(newRuns)
                    self.runs = newRuns
                    self.lastError = nil
                case .failure(let err):
                    self.lastError = err.localizedDescription
                }
            }
        }
    }

    /// Triggers a preview CI notification banner in the closed notch.
    func triggerSimulatedBanner(passed: Bool) {
        let repo = selectedRepo
        let sampleRun = runs.first
        let title = sampleRun?.displayTitle ?? (passed ? "Build & Release Universal macOS App" : "Unit Tests & SwiftLint Check")
        let branch = sampleRun?.branch ?? "main"
        let url = sampleRun?.htmlURL ?? URL(string: "https://github.com/\(repo)/actions")

        let banner = Banner(
            icon: passed ? "checkmark.seal.fill" : "xmark.octagon.fill",
            tint: passed ? .green : .red,
            badge: passed ? "CI Passed" : "CI Failed",
            title: title,
            subtitle: "\(repo) · \(branch)",
            actionTitle: passed ? "View Run" : "Inspect Logs",
            actionURL: url,
            duration: 10,
            kind: passed ? .success : .attention
        )
        onBanner?(banner)
    }

    private func processRunTransitions(_ newRuns: [CIWorkflowRun]) {
        for run in newRuns {
            let previousStatus = knownRunStatuses[run.id]
            knownRunStatuses[run.id] = run.status

            guard hasCompletedInitialFetch,
                  let previousStatus,
                  previousStatus != "completed",
                  run.status == "completed",
                  AppSettings.shared.ciNotifyBanner else {
                continue
            }

            let passed = run.conclusion == "success"
            let failed = run.conclusion == "failure" || run.conclusion == "timed_out" || run.conclusion == "cancelled"
            guard passed || failed else { continue }

            let banner = Banner(
                icon: passed ? "checkmark.seal.fill" : "xmark.octagon.fill",
                tint: passed ? .green : .red,
                badge: passed ? "CI Passed" : "CI Failed",
                title: run.displayTitle,
                subtitle: "\(run.repo) · \(run.branch)",
                actionTitle: passed ? "View Run" : "Inspect Logs",
                actionURL: run.htmlURL,
                duration: 12,
                kind: passed ? .success : .attention
            )
            onBanner?(banner)
        }
        hasCompletedInitialFetch = true
    }

    // MARK: - Local Compiler Process Detection

    func scanLocalBuilds() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let detected = Self.fetchLocalBuildProcesses()
            DispatchQueue.main.async {
                self?.localBuilds = detected
            }
        }
    }

    private static func fetchLocalBuildProcesses() -> [LocalBuildProcess] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-axo", "pid=,comm=,args="]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var results: [LocalBuildProcess] = []
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.split(maxSplits: 2, whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 2, let pid = Int32(parts[0]) else { continue }
                let comm = (parts[1] as NSString).lastPathComponent.lowercased()
                let args = parts.count > 2 ? parts[2] : parts[1]
                let lowerArgs = args.lowercased()

                let tool: String?
                if comm == "xcodebuild" {
                    tool = "xcodebuild"
                } else if comm == "swift-build" || lowerArgs.contains("swift build") {
                    tool = "swift build"
                } else if comm == "cargo" && (lowerArgs.contains("cargo build") || lowerArgs.contains("cargo check") || lowerArgs.contains("cargo test")) {
                    tool = "cargo"
                } else if lowerArgs.contains("vite build") || lowerArgs.contains("next build") || lowerArgs.contains("npm run build") || lowerArgs.contains("pnpm build") {
                    tool = "web build"
                } else if comm == "go" && lowerArgs.contains("go build") {
                    tool = "go build"
                } else {
                    tool = nil
                }

                if let tool {
                    results.append(LocalBuildProcess(pid: pid, tool: tool, commandLine: args))
                }
            }
            return results
        } catch {
            return []
        }
    }

    // MARK: - GitHub CLI & REST Fetchers

    private func fetchRunsViaGH(repo: String) -> Result<[CIWorkflowRun], Error>? {
        let ghPaths = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = ghPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }

        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ghPath)
        proc.arguments = [
            "run", "list",
            "-R", repo,
            "--limit", "8",
            "--json", "databaseId,name,displayTitle,status,conclusion,headBranch,event,url,updatedAt,workflowName"
        ]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }

            let iso = ISO8601DateFormatter()
            let parsed: [CIWorkflowRun] = items.compactMap { dict in
                guard let id = dict["databaseId"] as? Int else { return nil }
                let workflowName = (dict["workflowName"] as? String) ?? (dict["name"] as? String) ?? "Workflow"
                let displayTitle = (dict["displayTitle"] as? String) ?? workflowName
                let status = (dict["status"] as? String) ?? "completed"
                let conclusion = dict["conclusion"] as? String
                let branch = (dict["headBranch"] as? String) ?? "main"
                let event = (dict["event"] as? String) ?? "push"
                let urlStr = dict["url"] as? String
                let updatedStr = dict["updatedAt"] as? String
                return CIWorkflowRun(
                    id: id,
                    repo: repo,
                    workflowName: workflowName,
                    displayTitle: displayTitle,
                    branch: branch,
                    status: status,
                    conclusion: conclusion,
                    event: event,
                    htmlURL: urlStr.flatMap(URL.init(string:)),
                    updatedAt: updatedStr.flatMap { iso.date(from: $0) }
                )
            }
            return .success(parsed)
        } catch {
            return nil
        }
    }

    private func fetchRunsViaREST(repo: String) -> Result<[CIWorkflowRun], Error> {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/actions/runs?per_page=8") else {
            return .failure(NSError(domain: "CIBuildMonitor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid repository slug"]))
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("OpenNotchi", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<[CIWorkflowRun], Error> = .failure(
            NSError(domain: "CIBuildMonitor", code: -2, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                outcome = .failure(error)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = http.statusCode == 404 ? "Repo not found or private (install `gh` CLI for private repos)" : "GitHub API HTTP \(http.statusCode)"
                outcome = .failure(NSError(domain: "CIBuildMonitor", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg]))
                return
            }
            guard let data,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = root["workflow_runs"] as? [[String: Any]] else {
                outcome = .failure(NSError(domain: "CIBuildMonitor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                return
            }

            let iso = ISO8601DateFormatter()
            let parsed: [CIWorkflowRun] = items.compactMap { dict in
                guard let id = dict["id"] as? Int else { return nil }
                let workflowName = (dict["name"] as? String) ?? "Workflow"
                let displayTitle = (dict["display_title"] as? String) ?? workflowName
                let status = (dict["status"] as? String) ?? "completed"
                let conclusion = dict["conclusion"] as? String
                let branch = (dict["head_branch"] as? String) ?? "main"
                let event = (dict["event"] as? String) ?? "push"
                let urlStr = dict["html_url"] as? String
                let updatedStr = dict["updated_at"] as? String
                return CIWorkflowRun(
                    id: id,
                    repo: repo,
                    workflowName: workflowName,
                    displayTitle: displayTitle,
                    branch: branch,
                    status: status,
                    conclusion: conclusion,
                    event: event,
                    htmlURL: urlStr.flatMap(URL.init(string:)),
                    updatedAt: updatedStr.flatMap { iso.date(from: $0) }
                )
            }
            outcome = .success(parsed)
        }.resume()

        _ = semaphore.wait(timeout: .now() + 11)
        return outcome
    }

    private static func detectDefaultRepo() -> String? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        proc.arguments = ["config", "--get", "remote.origin.url"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            let slug = cleanRepoSlug(raw)
            return slug.contains("/") ? slug : nil
        } catch {
            return nil
        }
    }

    static func cleanRepoSlug(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix(".git") { s.removeLast(4) }
        if let range = s.range(of: "github.com[:/]", options: .regularExpression) {
            s = String(s[range.upperBound...])
        }
        let parts = s.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            return "\(parts[0])/\(parts[1])"
        }
        return s
    }
}

