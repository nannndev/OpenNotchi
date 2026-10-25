import Foundation

/// Usage per configured account, rescanned at most every 60 s while AI features are on.
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published private(set) var reports: [UsageReport] = []
    @Published private(set) var is9RouterConnected: Bool = false
    @Published private(set) var scanning = false
    /// Today's top models across 9router accounts (empty without 9router).
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

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var allReports: [UsageReport] = []
            var from9Router = false
            var models: [(model: String, tokens: Int, cost: Double)] = []

            // 1. Prioritize 9router if available: fetches all multi-accounts per provider
            if NineRouterService.shared.isAvailable {
                let nineReports = NineRouterService.shared.fetchReports()
                if !nineReports.isEmpty {
                    allReports = nineReports
                    from9Router = true
                    models = NineRouterService.shared.todayModels()
                }
            }

            // 2. If 9router is not available or returned empty, scan local directories
            if allReports.isEmpty {
                allReports = localAccounts.map { AIUsage.report($0) }
            } else {
                // 9router already logs every request it routes, per account. A local folder for a tool 9router
                // covers would count the same tokens again, so only tools 9router doesn't know are added.
                // Those folders still feed the Agents list.
                let routed = Set(allReports.map(\.account.tool))
                for acc in localAccounts where !routed.contains(acc.tool) {
                    let r = AIUsage.report(acc)
                    if r.found {
                        allReports.append(r)
                    }
                }
            }

            DispatchQueue.main.async {
                self?.reports = allReports
                self?.is9RouterConnected = from9Router
                self?.topModels = models
                self?.scanning = false
            }
        }
    }

    func toggleAccountActive(id: UUID, connectionId: String?, active: Bool) {
        // Optimistic local update
        if let idx = reports.firstIndex(where: { $0.account.id == id }) {
            reports[idx].account.isActive = active
        }
        if let connId = connectionId {
            NineRouterService.shared.setConnectionActive(id: connId, active: active) { [weak self] _ in
                self?.refresh(force: true)
            }
        }
    }

    /// The compact closed-notch meter: a hot 9router / Codex / Claude window.
    var closedMeter: (label: String, fraction: Double, hot: Bool)? {
        for r in reports {
            if r.isFrom9Router && r.account.isActive {
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
