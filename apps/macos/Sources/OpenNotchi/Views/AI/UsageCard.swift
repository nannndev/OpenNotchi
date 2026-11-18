import SwiftUI

struct UsageCard: View {
    let report: UsageReport
    @Environment(\.notchAccent) private var accent
    @EnvironmentObject private var usage: AIUsageManager
    @EnvironmentObject private var vm: NotchViewModel
    @State private var isHovering = false
    @State private var testingAccount = false
    @State private var testFeedback: (ok: Bool, text: String)?

    private var toolTint: Color { report.tint }

    private var healthColor: Color {
        if !report.account.isActive { return .gray }
        switch report.quota.health {
        case .healthy: return .green
        case .warning: return .orange
        case .exhausted: return .red
        }
    }

    private var healthLabel: String {
        if !report.account.isActive { return "OFF" }
        if report.testStatus == "unavailable" || (report.lastError?.contains("rate_limit") == true) {
            return "RATE LIMIT"
        }
        return report.quota.health.rawValue.uppercased()
    }

    var body: some View {
        let q = report.quota
        let cardHeight: CGFloat = vm.isAiExpanded ? 260 : 210

        VStack(alignment: .leading, spacing: 6) {
            // Header: Tool Icon, Name, Provider & Priority, Interactive ON/OFF Toggle & Health Pill
            HStack(spacing: 6) {
                ReportLogo(report: report, size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(report.account.name)
                        .font(.system(size: 11.5, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Text(report.sourceName)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let p = report.account.priority {
                            Text("· P\(p)")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(toolTint)
                        }
                    }
                }

                Spacer(minLength: 4)

                if report.isFromGateway && (isHovering || testingAccount), let connId = report.account.connectionId {
                    Button {
                        testingAccount = true
                        testFeedback = nil
                        Task {
                            let res = await NotchiGatewayService.shared.testAccount(
                                provider: report.provider ?? report.sourceKey,
                                id: connId
                            )
                            testingAccount = false
                            testFeedback = (res.ok, res.message)
                        }
                    } label: {
                        HStack(spacing: 2.5) {
                            if testingAccount {
                                ProgressView().controlSize(.mini).scaleEffect(0.6)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                            }
                            Text(testingAccount ? "…" : "Ping")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.15))
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 0.8))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(testingAccount)
                    .help("Test live Gateway connection for this account")
                }

                // Interactive Gateway ON / OFF Toggle Pill
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        usage.toggleAccountActive(report, active: !report.account.isActive)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(report.account.isActive ? Color.green : Color.gray)
                            .frame(width: 5, height: 5)
                        Text(report.account.isActive ? "ON" : "OFF")
                            .font(.system(size: 8, weight: .heavy))
                    }
                    .foregroundStyle(report.account.isActive ? Color.green : Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(report.account.isActive ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(report.account.isActive ? Color.green.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(report.account.isActive ? "Active in Gateway. Click to toggle OFF." : "Inactive. Click to toggle ON.")

                // Health status badge
                Text(healthLabel)
                    .font(.system(size: 7.5, weight: .heavy))
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(healthColor.opacity(0.18)).overlay(Capsule().stroke(healthColor.opacity(0.35), lineWidth: 0.8)))
            }

            if let coolingUntil = report.coolingUntil, coolingUntil > .now {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let secs = Int(coolingUntil.timeIntervalSince(ctx.date))
                    if secs > 0 {
                        HStack(spacing: 4) {
                            Text("⏳ Cooldown · \(secs)s")
                                .font(.system(size: 9, weight: .bold).monospacedDigit())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.14))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.35), lineWidth: 0.8))
                        )
                    }
                }
            }

            if let err = report.lastError, !err.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8.5))
                    Text(err)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(.orange)
                .help(err)
            }

            if let feedback = testFeedback {
                HStack(spacing: 4) {
                    Image(systemName: feedback.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 8.5))
                    Text(feedback.text)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(feedback.ok ? .green : .red)
                .help(feedback.text)
            }

            if !report.found {
                note("No logs found in \(report.account.dir)")
            } else if report.isFromGateway {
                // Gateway Quota Bars (e.g. session 5h and weekly 7d, or multiple models)
                if !report.quotas.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(report.quotas, id: \.name) { q in
                            GatewayQuotaBar(quota: q)
                        }
                    }
                } else if let plan = report.planName {
                    stat("Plan", plan)
                }

                stat("Today", "\(formatTokens(report.today.tokens)) \(report.today.cost > 0 ? "· " + formatCost(report.today.cost) : "tokens")")
                sparkline
            } else {
                // Quota bar / Block gauge (Directory Fallback)
                if report.account.tool == .codex {
                    if let w = report.limits?.primary { LimitBar(window: w) }
                    if let w = report.limits?.secondary { LimitBar(window: w) }
                    if report.limits == nil { note("No rate limits reported yet") }
                } else if let block = report.block {
                    VStack(alignment: .leading, spacing: 3) {
                        stat("5h block", formatTokens(block.tokens.tokens))
                        let pct = min(100, max(0, q.percent))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12)).frame(height: 5.5)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: q.health == .exhausted ? [.orange, .red] : [accent.highlight.opacity(0.8), accent.highlight],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(3.5, geo.size.width * CGFloat(pct / 100)), height: 5.5)
                            }
                        }
                        .frame(height: 5.5)
                        if let resets = q.resetsText {
                            note("\(resets) \(block.tokens.cost > 0 ? "· " + formatCost(block.tokens.cost) : "")")
                        }
                    }
                } else {
                    stat("5h block", "Idle (None active)")
                }

                stat("Today", "\(formatTokens(report.today.tokens)) \(report.today.cost > 0 ? "· " + formatCost(report.today.cost) : "tokens")")
                sparkline
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(width: 230, height: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(.white.opacity(isHovering ? 0.08 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(healthColor.opacity(report.account.isActive ? 0.25 : 0.08), lineWidth: 1))
        )
        .opacity(report.account.isActive ? 1.0 : 0.55)
        .onHover { isHovering = $0 }
    }

    private var sparkline: some View {
        let peak = max(1, report.days.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(Array(report.days.enumerated()), id: \.offset) { i, tokens in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == report.days.count - 1 ? accent.highlight : .white.opacity(0.25))
                    .frame(height: max(2, 20 * CGFloat(tokens) / CGFloat(peak)))
            }
        }
        .frame(height: 20, alignment: .bottom)
        .help("Tokens per day, last 7 days")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 10.5))
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(2)
    }
}

struct GatewayQuotaBar: View {
    let quota: GatewayQuota
    @Environment(\.notchAccent) private var accent

    private var barColor: Color {
        if quota.remainingPercentage <= 10 { return .red }
        if quota.remainingPercentage <= 30 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(quota.name)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(quota.unlimited ? "Unlimited" : "\(Int(quota.remainingPercentage.rounded()))% left")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(barColor)
            }
            .font(.system(size: 9.5))

            if !quota.unlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(2, geo.size.width * CGFloat(min(100.0, max(0.0, quota.remainingPercentage)) / 100.0)))
                    }
                }
                .frame(height: 4.5)
            }

            // Prominent reset info displaying both relative countdown and exact local time
            HStack(spacing: 3) {
                if let resets = quota.resetAt, resets > .now {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text(formatResetDetail(resets))
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                } else if quota.unlimited {
                    Image(systemName: "infinity")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                    Text("Unlimited quota")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                } else if quota.remainingPercentage >= 99.0 {
                    Image(systemName: "sparkles")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.green)
                    Text("Full · 5h window starts on use")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                    Text("Rolling window")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LimitBar: View {
    let window: RateWindow

    var body: some View {
        let pct = min(100, max(0, window.usedPercent))
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(window.label).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(pct.rounded()))%").fontWeight(.semibold).monospacedDigit()
            }
            .font(.system(size: 11))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(pct >= 80 ? Color.orange : .green).frame(width: geo.size.width * pct / 100)
                }
            }
            .frame(height: 5)
            HStack(spacing: 3) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(formatResetDetail(window.resetsAt))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
