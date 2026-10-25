import SwiftUI

func emptyState(_ text: String, icon: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.secondary)
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

extension AgentTool {
    var tint: Color {
        switch self {
        case .claude: return .orange
        case .antigravity: return Color(red: 0.65, green: 0.45, blue: 0.98)
        case .codex: return .green
        case .commandcode: return .cyan
        }
    }
}

/// Provider logo, falling back to the SF Symbol when the bundled PNG is missing (e.g. `swift run`).
struct ToolLogo: View {
    let tool: AgentTool
    var size: CGFloat = 20

    var body: some View {
        if let logo = tool.logo {
            Image(nsImage: logo)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else {
            Image(systemName: tool.icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(tool.tint)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.24).fill(tool.tint.opacity(0.18)))
        }
    }
}

// MARK: - Compact & list layouts

/// The quota closest to running out, which is what decides whether an account is usable.
func tightestQuota(_ report: UsageReport) -> NineRouterQuota? {
    report.quotas.filter { !$0.unlimited }.min { $0.remainingPercentage < $1.remainingPercentage }
}

func quotaColor(_ remaining: Double) -> Color {
    remaining <= 10 ? .red : remaining <= 30 ? .orange : .green
}

/// ON/OFF switch shared by the compact and list layouts.
