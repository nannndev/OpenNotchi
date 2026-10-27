import AppKit
import SwiftUI

/// Side panel for one agent session: a big Notchi acting out its state, where it runs, and its last message.
struct AgentDetail: View {
    let session: AgentSession
    let onClose: () -> Void

    private var stateColor: Color {
        switch session.state {
        case .working: return .cyan
        case .needsYou: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    /// What Notchi says about the state, in place of a bare label.
    private var caption: String {
        switch session.state {
        case .working: return "Working on it…"
        case .needsYou: return "Needs your OK"
        case .done: return "All done!"
        case .idle: return "Taking a nap"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ToolLogo(tool: session.tool, size: 16)
                Text(session.tool.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .padding(5)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            VStack(spacing: 4) {
                NotchiMascot(mood: session.state.mood, size: 64)
                Text(caption)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(stateColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.project.isEmpty ? session.tool.displayName : session.project)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                if !session.cwd.isEmpty {
                    Text(abbreviated(session.cwd))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(session.cwd)
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("Last activity \(Self.ago(session.updatedAt, now: context.date))")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }

            if let message = session.message, !message.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(session.state == .needsYou ? Color.orange : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 70)
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 8).fill(stateColor.opacity(0.1)))
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button {
                    AgentMonitor.activateTerminal(for: session.tool)
                } label: {
                    Label("Open terminal", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(stateColor)

                if !session.cwd.isEmpty {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: session.cwd))
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Open the project folder in Finder")
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(stateColor.opacity(0.35), lineWidth: 1))
        )
    }

    /// `~/…` instead of the home folder path.
    private func abbreviated(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func ago(_ date: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60) min ago" }
        return "\(s / 3600) h ago"
    }
}
