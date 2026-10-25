import Foundation

struct UsageTotals: Equatable {
    var tokens = 0
    /// Estimated USD; only models in the price table add to it.
    var cost = 0.0
}

struct RateWindow: Equatable {
    var usedPercent: Double
    var windowMinutes: Int
    var resetsAt: Date

    /// "5h" / "weekly" / "1d" from the window length.
    var label: String {
        if windowMinutes == 10080 { return "weekly" }
        if windowMinutes % 1440 == 0 { return "\(windowMinutes / 1440)d" }
        return windowMinutes % 60 == 0 ? "\(windowMinutes / 60)h" : "\(windowMinutes)m"
    }
}

struct CodexLimits: Equatable {
    var planType: String?
    var primary: RateWindow?
    var secondary: RateWindow?
}

struct UsageReport: Identifiable {
    var account: AIAccount
    var id: UUID { account.id }
    /// False when the folder has no session logs and no 9router connection found.
    var found = false
    var today = UsageTotals()
    /// The running 5-hour block (Claude Code).
    var block: (start: Date, tokens: UsageTotals)?
    /// Tokens per local day, oldest first, today last.
    var days = [Int](repeating: 0, count: 7)
    var limits: CodexLimits?

    // 9router multi-account enhancements:
    var quotas: [NineRouterQuota] = []
    var planName: String?
    var testStatus: String?
    var lastError: String?
    var isFrom9Router: Bool = false
}

enum AccountHealth: String {
    case healthy, warning, exhausted
}

struct AccountQuota {
    var percent: Double
    var label: String
    var resetsText: String?
    var health: AccountHealth
}

extension UsageReport {
    var quota: AccountQuota {
        if isFrom9Router {
            if !account.isActive {
                return AccountQuota(percent: 100, label: "Inactive", resetsText: "Disabled in 9router", health: .exhausted)
            }
            if testStatus == "unavailable" || (lastError?.contains("rate_limit") == true) {
                let reset = quotas.compactMap(\.resetAt).filter { $0 > .now }.min()
                let resetsText = reset != nil ? resetsIn(reset!) : "Rate limited"
                return AccountQuota(percent: 100, label: "Rate Limit", resetsText: resetsText, health: .exhausted)
            }

            // Find lowest remaining percentage among active session and weekly quotas
            let activeQuotas = quotas.filter { !$0.unlimited && $0.total > 0 }
            if let lowest = activeQuotas.min(by: { $0.remainingPercentage < $1.remainingPercentage }) {
                let usedPct = min(100.0, max(0.0, 100.0 - lowest.remainingPercentage))
                let h: AccountHealth = lowest.remainingPercentage <= 10 ? .exhausted : lowest.remainingPercentage <= 30 ? .warning : .healthy
                let resetsText = lowest.resetAt != nil && lowest.resetAt! > .now ? resetsIn(lowest.resetAt!) : nil
                return AccountQuota(percent: usedPct, label: "\(Int(lowest.remainingPercentage.rounded()))% left", resetsText: resetsText, health: h)
            }
            return AccountQuota(percent: 0, label: "Active", resetsText: nil, health: .healthy)
        }

        if let primary = limits?.primary {
            let pct = min(100, max(0, primary.usedPercent))
            let h: AccountHealth = pct >= 90 ? .exhausted : pct >= 70 ? .warning : .healthy
            let resets = primary.resetsAt > .now ? resetsIn(primary.resetsAt) : nil
            return AccountQuota(percent: pct, label: "\(Int(pct.rounded()))%", resetsText: resets, health: h)
        }
        if let block, block.start.addingTimeInterval(5 * 3600) > .now {
            let elapsed = min(100, max(0, Date.now.timeIntervalSince(block.start) / (5 * 36)))
            let h: AccountHealth = block.tokens.tokens >= 250_000 ? .warning : .healthy
            let resets = resetsIn(block.start.addingTimeInterval(5 * 3600))
            return AccountQuota(percent: elapsed, label: formatTokens(block.tokens.tokens), resetsText: resets, health: h)
        }
        return AccountQuota(percent: 0, label: "Idle", resetsText: nil, health: .healthy)
    }
}
