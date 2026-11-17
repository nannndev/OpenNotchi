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

struct GatewayQuota: Equatable {
    var name: String
    var used: Double
    var total: Double
    var remaining: Double
    var remainingPercentage: Double
    var resetAt: Date?
    var unlimited: Bool

    var isExhausted: Bool {
        if unlimited { return false }
        if total > 0 && used >= total { return true }
        return remainingPercentage <= 0.0
    }

    private static let poolLabels: [(key: String, label: String)] = [
        ("gemini_session", "Gemini (5h)"),
        ("claude_gpt_session", "Claude & GPT (5h)"),
        ("gemini_weekly", "Gemini (Weekly)"),
        ("claude_gpt_weekly", "Claude & GPT (Weekly)"),
    ]

    static func displayQuotas(_ quotas: [GatewayQuota]) -> [GatewayQuota] {
        let pools = poolLabels.compactMap { pool -> GatewayQuota? in
            guard var q = quotas.first(where: { $0.name == pool.key }) else { return nil }
            q.name = pool.label
            return q
        }
        return pools.isEmpty ? quotas.sorted { $0.name < $1.name } : pools
    }
}

struct DayStat: Identifiable {
    var date: String
    var requests: Int
    var input: Int
    var cached: Int
    var output: Int
    var cost: Double
    var id: String { date }
}

struct RecentRequest: Identifiable {
    var id: Int64
    var date: Date
    var model: String
    var provider: String
    var input: Int
    var output: Int
    var ok: Bool
}

struct ModelStat: Identifiable {
    var id: String
    var tokens: Int
    var cost: Double
    var model: String { String(id.split(separator: "|").first ?? Substring(id)) }
    var provider: String { id.split(separator: "|").dropFirst().first.map(String.init) ?? "" }
}

struct UsageReport: Identifiable {
    var account: AIAccount
    var id: UUID { account.id }
    /// False when the folder has no session logs and no Gateway connection found.
    var found = false
    var today = UsageTotals()
    /// The running 5-hour block (Claude Code).
    var block: (start: Date, tokens: UsageTotals)?
    /// Tokens per local day, oldest first, today last.
    var days = [Int](repeating: 0, count: 7)
    var limits: CodexLimits?

    // Multi-account gateway enhancements:
    var quotas: [GatewayQuota] = []
    var planName: String?
    var testStatus: String?
    var lastError: String?
    var isFromGateway: Bool = false
    /// Gateway provider id ("codex", "kimi", "cline", …); nil for local session folders.
    var provider: String?
    /// The gateway is skipping this account after a rate limit until then.
    var coolingUntil: Date?

    /// Provider name for gateway accounts, the tool name for local folders.
    var sourceName: String { provider.map(GatewayProvider.name) ?? account.tool.displayName }
    /// Key used to group and filter accounts by where they come from.
    var sourceKey: String { provider ?? account.tool.rawValue }
}

/// Display names for gateway providers that aren't local agent tools.
enum GatewayProvider {
    static func name(_ id: String) -> String {
        switch id {
        case "claude": return "Claude"
        case "codex": return "ChatGPT / Codex"
        case "copilot": return "GitHub Copilot"
        case "gemini-cli": return "Gemini CLI"
        case "kimi": return "Kimi Code"
        case "muse": return "Muse Code"
        case "nous": return "Nous Research"
        case "kilocode": return "Kilo Code"
        case "cline": return "Cline"
        case "minimax-code": return "MiniMax Code"
        case "minimax-code-global": return "MiniMax Code (Global)"
        case "antigravity": return "Antigravity"
        case "grok-cli": return "Grok CLI"
        case "kiro": return "Kiro"
        default: return id.capitalized
        }
    }
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
        if isFromGateway {
            if !account.isActive {
                return AccountQuota(percent: 100, label: "Inactive", resetsText: "Disabled in Gateway", health: .exhausted)
            }
            if testStatus == "unavailable" || (lastError?.contains("rate_limit") == true) {
                let reset = coolingUntil ?? quotas.compactMap(\.resetAt).filter { $0 > .now }.min()
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
