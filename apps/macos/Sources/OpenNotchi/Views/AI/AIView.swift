import SwiftUI

/// The AI tab: agent status, usage per account, and Ask AI.
struct AIView: View {
    enum Section: String, CaseIterable {
        case usage = "Quota & Accounts"
        case analytics = "Analytics"
        case agents = "Agents"
        case ask = "Ask"

        var icon: String {
            switch self {
            case .usage: return "chart.bar.xaxis"
            case .analytics: return "chart.xyaxis.line"
            case .agents: return "cpu"
            case .ask: return "sparkles"
            }
        }
    }

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor
    @EnvironmentObject private var vm: NotchViewModel
    @AppStorage("aiSection") private var section: Section = .usage

    private var activeAgentCount: Int {
        agents.sessions.filter { $0.state == .working || $0.state == .needsYou }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Interactive Tab Bar & Expand/Collapse Controller
            HStack(spacing: 8) {
                // Custom Pill Tab Switcher
                HStack(spacing: 4) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                section = s
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: s.icon)
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(s.rawValue)
                                    .font(.system(size: 11, weight: section == s ? .bold : .medium))
                                if s == .agents && activeAgentCount > 0 {
                                    Circle()
                                        .fill(agents.sessions.contains(where: { $0.state == .needsYou }) ? Color.orange : Color.cyan)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .foregroundStyle(section == s ? Color.white : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                ZStack {
                                    if section == s {
                                        Capsule()
                                            .fill(Color.white.opacity(0.18))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                    } else {
                                        Capsule()
                                            .fill(Color.clear)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                )

                Spacer()

                // Expand / Collapse Notch Button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        vm.isAiExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.isAiExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(vm.isAiExpanded ? "Compact" : "Expand")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(vm.isAiExpanded ? Color.cyan : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(vm.isAiExpanded ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(vm.isAiExpanded ? Color.cyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(vm.isAiExpanded ? "Collapse notch to standard height" : "Expand notch downward for spacious view")
            }
            .padding(.horizontal, 4)

            Group {
                switch section {
                case .usage: UsageSection()
                case .analytics: AnalyticsSection()
                case .agents: AgentsSection()
                case .ask: AskSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 4)
    }
}
