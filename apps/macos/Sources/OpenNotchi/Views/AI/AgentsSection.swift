import SwiftUI

struct AgentsSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor

    /// Needs-you first, then working, done, idle; newest first inside each group.
    private var sorted: [AgentSession] {
        let rank: [AgentState: Int] = [.needsYou: 0, .working: 1, .done: 2, .idle: 3]
        return agents.sessions.sorted {
            (rank[$0.state] ?? 9, $1.updatedAt) < (rank[$1.state] ?? 9, $0.updatedAt)
        }
    }

    private func count(_ state: AgentState) -> Int {
        agents.sessions.filter { $0.state == state }.count
    }

    var body: some View {
        if !settings.aiAgents {
            emptyState("Agent status is off in Settings › AI.", icon: "terminal")
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    statPill(count(.needsYou), "needs you", .orange)
                    statPill(count(.working), "working", .cyan)
                    statPill(count(.done), "done", .green)
                    Spacer()
                    ForEach([AgentTool.claude, .codex, .antigravity, .commandcode], id: \.self) { launchButton($0) }
                }
                .padding(.horizontal, 2)

                if agents.sessions.isEmpty {
                    emptyAgents
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 6)], spacing: 6) {
                            ForEach(sorted) { AgentRow(session: $0) }
                        }
                        .padding(.horizontal, 2)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sorted.map(\.id))
                    }
                }
            }
        }
    }

    private func statPill(_ n: Int, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(n)").font(.system(size: 11, weight: .bold).monospacedDigit())
            Text(label).font(.system(size: 9.5, weight: .medium))
        }
        .foregroundStyle(n > 0 ? tint : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill((n > 0 ? tint : .white).opacity(n > 0 ? 0.15 : 0.05)))
    }

    private func launchButton(_ tool: AgentTool) -> some View {
        Button {
            AgentMonitor.activateTerminal(for: tool)
        } label: {
            ToolLogo(tool: tool, size: 20)
        }
        .buttonStyle(.plain)
        .help("Open \(tool.displayName)")
        .accessibilityLabel("Open \(tool.displayName)")
    }

    private var emptyAgents: some View {
        VStack(spacing: 10) {
            HStack(spacing: -6) {
                ForEach([AgentTool.claude, .codex, .antigravity, .commandcode], id: \.self) { tool in
                    ToolLogo(tool: tool, size: 34)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }
            }
            VStack(spacing: 3) {
                Text("No agents running")
                    .font(.system(size: 12.5, weight: .bold))
                Text("Start Claude Code, Codex, Antigravity or Command Code. Progress and approval prompts show up here.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AgentRow: View {
    let session: AgentSession
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var pulse = false

    private var stateColor: Color {
        switch session.state {
        case .working: return .cyan
        case .needsYou: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    var body: some View {
        Button {
            AgentMonitor.activateTerminal(for: session.tool)
        } label: {
            HStack(spacing: 9) {
                toolIcon
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(session.project.isEmpty ? session.tool.displayName : session.project)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text(timeAgo(session.updatedAt, now: context.date))
                                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 6, height: 6)
                            .opacity(session.state == .working && pulse ? 0.3 : 1)
                        Text(session.state.label.capitalized)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(stateColor)
                        Text("· \(session.tool.displayName)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if let msg = session.message, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundStyle(session.state == .needsYou ? Color.orange.opacity(0.9) : Color.secondary)
                            .lineLimit(2)
                    }
                }
                if hovering {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(alignment: .leading) {
                // State stripe along the leading edge.
                RoundedRectangle(cornerRadius: 2)
                    .fill(stateColor)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .help(session.message ?? "Open the session")
        .accessibilityLabel("\(session.tool.displayName), \(session.project), \(session.state.label)")
    }

    private var toolIcon: some View {
        ToolLogo(tool: session.tool, size: 28)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(session.state == .needsYou ? Color.orange.opacity(0.12) : Color.white.opacity(hovering ? 0.08 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(session.state == .needsYou ? Color.orange.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func timeAgo(_ date: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "now" }
        return s < 3600 ? "\(s / 60)m" : "\(s / 3600)h"
    }
}
