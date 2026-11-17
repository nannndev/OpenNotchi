import Foundation

/// Usage per configured account, rescanned at most every 60 s while AI features are on.
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published private(set) var reports: [UsageReport] = []
    @Published private(set) var isGatewayConnected: Bool = false
    @Published private(set) var scanning = false
    /// Today's top models across Gateway accounts.
    @Published private(set) var topModels: [(model: String, tokens: Int, cost: Double)] = []
    private var timer: Timer?
    private var accounts: [AIAccount] = []
    private var lastScan = Date.distantPast

    func configure(enabled: Bool, accounts: [AIAccount]) {
        let changed = accounts != self.accounts
        self.accounts = accounts
        guard enabled else {
            timer?.invalidate()
            timer = nil
            reports = []
            return
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        }
        if changed { lastScan = .distantPast }
        refresh()
    }

    func refresh(force: Bool = false) {
        guard !scanning, force || reports.isEmpty || Date.now.timeIntervalSince(lastScan) >= 15 else { return }
        scanning = true
        lastScan = .now
        let localAccounts = accounts
        let forceQuotas = force

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var allReports: [UsageReport] = []
            var fromGateway = false
            var models: [(model: String, tokens: Int, cost: Double)] = []

            // 1. Notchi Gateway accounts & reports
            if NotchiGatewayService.shared.isAvailable {
                let gwReports = NotchiGatewayService.shared.fetchReports(force: forceQuotas)
                if !gwReports.isEmpty {
                    allReports = gwReports
                    fromGateway = true
                    models = NotchiGatewayService.shared.analytics(days: 1).todayModels
                }
            }

            // 2. If Gateway has no accounts yet, scan local directories
            if allReports.isEmpty {
                allReports = localAccounts.map { AIUsage.report($0) }
            } else {
                // Gateway logs requests for routed accounts. Folders not routed are added directly.
                // Only providers that are also local tools (claude, codex, antigravity) can overlap.
                let routed = Set(allReports.compactMap { $0.provider.flatMap(AgentTool.init(rawValue:)) })
                for acc in localAccounts where !routed.contains(acc.tool) {
                    let r = AIUsage.report(acc)
                    if r.found {
                        allReports.append(r)
                    }
                }
            }

            DispatchQueue.main.async {
                self?.reports = allReports
                self?.isGatewayConnected = fromGateway
                self?.topModels = models
                self?.scanning = false
            }
        }
    }

    /// Pauses or resumes a gateway account; local folders can't be toggled.
    func toggleAccountActive(_ report: UsageReport, active: Bool) {
        guard let provider = report.provider, let connId = report.account.connectionId else { return }
        // Optimistic local update
        if let idx = reports.firstIndex(where: { $0.account.id == report.account.id }) {
            reports[idx].account.isActive = active
        }
        Task {
            try? await NotchiGatewayService.shared.toggleAccount(provider: provider, id: connId, enabled: active)
            self.refresh(force: true)
        }
    }

    /// The compact closed-notch meter: a hot Gateway / Codex / Claude window.
    var closedMeter: (label: String, fraction: Double, hot: Bool)? {
        for r in reports {
            if r.isFromGateway && r.account.isActive {
                for q in r.quotas where !q.unlimited && q.total > 0 && q.remainingPercentage <= 20 {
                    let pct = 100.0 - q.remainingPercentage
                    return ("\(r.account.name) \(Int(q.remainingPercentage.rounded()))%", pct / 100.0, true)
                }
            }
            for w in [r.limits?.primary, r.limits?.secondary].compactMap({ $0 }) where w.usedPercent >= 80 && w.resetsAt > .now {
                return ("\(w.label) \(Int(w.usedPercent.rounded()))%", w.usedPercent / 100, true)
            }
        }
        guard let block = reports.compactMap(\.block).first(where: { $0.start.addingTimeInterval(5 * 3600) > .now }) else { return nil }
        return (formatTokens(block.tokens.tokens), Date.now.timeIntervalSince(block.start) / (5 * 3600), false)
    }
}
