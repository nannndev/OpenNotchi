import AppKit
import SwiftUI

/// The AI tab: agent status, usage per account, and Ask AI.
struct AIView: View {
    enum Section: String, CaseIterable { case agents = "Agents", usage = "Usage", ask = "Ask" }

    @EnvironmentObject private var settings: AppSettings
    @AppStorage("aiSection") private var section: Section = .agents

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $section) {
                ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            Group {
                switch section {
                case .agents: AgentsSection()
                case .usage: UsageSection()
                case .ask: AskSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 4)
    }
}

private func emptyState(_ text: String, icon: String) -> some View {
    VStack(spacing: 6) {
        Image(systemName: icon).font(.system(size: 20, weight: .light))
        Text(text).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Agents

private struct AgentsSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor

    var body: some View {
        if !settings.aiAgents {
            emptyState("Agent status is off in Settings › AI.", icon: "terminal")
        } else if agents.sessions.isEmpty {
            emptyState("No Claude Code or Codex sessions in the last 30 minutes.", icon: "terminal")
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(agents.sessions) { AgentRow(session: $0) }
                }
            }
        }
    }
}

private struct AgentRow: View {
    let session: AgentSession
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    private var chipColor: Color {
        switch session.state {
        case .working: return accent.highlight
        case .needsYou: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    var body: some View {
        Button {
            AgentMonitor.activateTerminal(for: session.tool)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: session.tool.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
                Text(session.project.isEmpty ? session.tool.displayName : session.project)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text(session.state == .needsYou ? session.message ?? "" : session.tool.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    if session.state == .working {
                        ProgressView().controlSize(.mini).tint(chipColor)
                    }
                    Text(session.state.label)
                }
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(chipColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(chipColor.opacity(0.18)))
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(timeAgo(session.updatedAt, now: context.date))
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hovering ? 0.1 : 0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(session.message ?? "Open the terminal")
        .accessibilityLabel("\(session.tool.displayName), \(session.project), \(session.state.label)")
    }

    private func timeAgo(_ date: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "now" }
        return s < 3600 ? "\(s / 60)m" : "\(s / 3600)h"
    }
}

// MARK: - Usage

private struct UsageSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var usage: AIUsageManager

    var body: some View {
        if settings.aiAccounts.isEmpty {
            emptyState("Add a Claude Code or Codex folder in Settings › AI.", icon: "chart.bar")
        } else if usage.reports.isEmpty {
            emptyState("Reading usage…", icon: "chart.bar")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(usage.reports) { UsageCard(report: $0) }
                }
            }
            .onAppear { usage.refresh() }
        }
    }
}

private struct UsageCard: View {
    let report: UsageReport
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(report.account.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                Spacer()
                if let plan = report.limits?.planType {
                    Text(plan).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
            }
            if !report.found {
                note("No sessions found in \(report.account.dir)")
            } else if report.account.tool == .codex {
                if let w = report.limits?.primary { LimitBar(window: w) }
                if let w = report.limits?.secondary { LimitBar(window: w) }
                if report.limits == nil { note("No rate limits reported yet") }
                stat("Today", "\(formatTokens(report.today.tokens)) tokens")
            } else {
                stat("Today", "\(formatTokens(report.today.tokens)) · \(formatCost(report.today.cost))")
                stat("5h block", report.block.map { "\(formatTokens($0.tokens.tokens)) · \(formatCost($0.tokens.cost))" } ?? "not active")
                if let block = report.block {
                    note("\(resetsIn(block.start.addingTimeInterval(5 * 3600))) · cost is an estimate")
                }
                sparkline
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 200, height: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
    }

    private var sparkline: some View {
        let peak = max(1, report.days.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(report.days.enumerated()), id: \.offset) { i, tokens in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == report.days.count - 1 ? accent.highlight : .white.opacity(0.25))
                    .frame(height: max(2, 22 * CGFloat(tokens) / CGFloat(peak)))
            }
        }
        .frame(height: 22, alignment: .bottom)
        .help("Tokens per day, last 7 days")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 11))
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 9.5)).foregroundStyle(.tertiary).lineLimit(2)
    }
}

private struct LimitBar: View {
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
            Text(resetsIn(window.resetsAt)).font(.system(size: 9.5)).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Ask

private struct AskSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @Environment(\.notchAccent) private var accent
    @State private var text = ""
    @State private var answer: String?
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var copied = false

    private var lyricLine: String? {
        guard let info = media.info else { return nil }
        return lyrics.currentLine(at: info.position(at: .now))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("Ask anything…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                    .onSubmit { send(text) }
                    .onExitCommand(perform: reset)
                if task != nil {
                    ProgressView().controlSize(.small)
                } else {
                    iconButton("arrow.up.circle.fill", help: "Send") { send(text) }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if answer != nil || error != nil || !text.isEmpty {
                    iconButton("xmark.circle.fill", help: "Clear", action: reset)
                }
            }
            HStack(spacing: 6) {
                ForEach(QuickAction.allCases) { action in
                    Button { quick(action) } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(task != nil || (action == .explain && lyricLine == nil))
                    .help(action == .explain ? "Uses the current lyric line" : "Uses the text on the clipboard")
                }
                Spacer()
            }
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let error {
                        Text(error).foregroundStyle(.orange)
                    } else if let answer {
                        Text(answer).textSelection(.enabled)
                    } else {
                        Text("Type a question, or use a quick action on the clipboard or the current lyric line. Provider: \(settings.aiProvider.displayName).")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(alignment: .bottomTrailing) {
                if let answer {
                    iconButton(copied ? "checkmark" : "doc.on.doc", help: "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer, forType: .string)
                        copied = true
                    }
                }
            }
        }
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(accent.highlight)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func quick(_ action: QuickAction) {
        if action == .explain {
            guard let line = lyricLine else { return }
            send(action.prompt(line, song: media.info.map { ($0.title, $0.artist) }))
        } else {
            guard let clip = NSPasteboard.general.string(forType: .string), !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                error = "The clipboard has no text."
                return
            }
            send(action.prompt(clip))
        }
    }

    private func send(_ prompt: String) {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, task == nil else { return }
        (answer, error, copied) = (nil, nil, false)
        task = Task { @MainActor in
            do {
                answer = try await AIAssistant.ask(prompt, settings: settings)
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            task = nil
        }
    }

    private func reset() {
        task?.cancel()
        (task, text, answer, error, copied) = (nil, "", nil, nil, false)
    }
}
