import AppKit
import SwiftUI

/// Popover/sheet for 1-click routing of Claude Code and copying ready-to-use configs for Cursor, Cline, Continue, and shell tools.
struct GatewayClientConfigView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var isClaudeRouted = false
    @State private var claudeStatus: (ok: Bool, text: String)?
    @State private var copiedId: String?

    private var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
    }

    private var claudeSettingsURL: URL {
        claudeDir.appendingPathComponent("settings.json")
    }

    private var activeModel: String {
        let m = settings.aiGatewayModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "auto" : m
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Connect Your Tools")
                        .font(.system(size: 13, weight: .bold))
                    Text("Endpoint \(NotchiGatewayService.v1BaseURL)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            Divider()

            // 1. 1-Click Claude Code Configuration
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isClaudeRouted ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                        Text("Claude Code (~/.claude/settings.json)")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    Spacer()
                    Button(isClaudeRouted ? "Restore Direct Connection" : "Route Claude Code via Gateway") {
                        toggleClaudeRouting()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isClaudeRouted ? .orange : .accentColor)
                    .controlSize(.small)
                }

                Text(
                    isClaudeRouted
                        ? "Claude Code requests are routed through Notchi Gateway on \(NotchiGatewayService.baseURL) with multi-account fallback."
                        : "Merges ANTHROPIC_BASE_URL=\(NotchiGatewayService.baseURL) into ~/.claude/settings.json (with .gateway.bak backup)."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let claudeStatus {
                    Label(claudeStatus.text, systemImage: claudeStatus.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(claudeStatus.ok ? .green : .red)
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.05)))

            // 2. Ready-to-Copy Snippets
            VStack(alignment: .leading, spacing: 8) {
                Text("Ready-to-Copy Snippets")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                snippetRow(
                    id: "shell",
                    title: "Shell / Terminal (zsh / bash)",
                    code: "export OPENAI_BASE_URL=\"\(NotchiGatewayService.v1BaseURL)\" OPENAI_API_KEY=\"eay-gateway\""
                )

                snippetRow(
                    id: "ide",
                    title: "Cursor / Continue / Cline",
                    display: "Base URL: \(NotchiGatewayService.v1BaseURL)\nAPI Key: eay-gateway   ·   Model: \(activeModel)",
                    code: NotchiGatewayService.v1BaseURL,
                    copyLabel: "Copy URL"
                )

                snippetRow(
                    id: "curl",
                    title: "cURL Quick Test",
                    code: "curl \(NotchiGatewayService.v1BaseURL)/chat/completions -H \"Content-Type: application/json\" -d '{\"model\":\"\(activeModel)\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}'"
                )
            }
        }
        .padding(14)
        .frame(width: 400)
        .onAppear { refreshClaudeStatus() }
    }

    private func snippetRow(id: String, title: String, display: String? = nil, code: String, copyLabel: String = "Copy") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation { copiedId = id }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedId == id {
                            withAnimation { copiedId = nil }
                        }
                    }
                } label: {
                    Label(copiedId == id ? "Copied" : copyLabel, systemImage: copiedId == id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(display ?? code)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
        }
    }

    private func refreshClaudeStatus() {
        guard let data = try? Data(contentsOf: claudeSettingsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = obj["env"] as? [String: Any],
              let url = env["ANTHROPIC_BASE_URL"] as? String else {
            isClaudeRouted = false
            return
        }
        isClaudeRouted = url == NotchiGatewayService.baseURL
    }

    private func toggleClaudeRouting() {
        let enable = !isClaudeRouted
        do {
            let raw = try? Data(contentsOf: claudeSettingsURL)
            var current: [String: Any] = [:]
            if let raw, !String(decoding: raw, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
                    throw AIError("~/.claude/settings.json is not a valid JSON object.")
                }
                current = obj
            }

            var env = current["env"] as? [String: Any] ?? [:]
            if enable {
                env["ANTHROPIC_BASE_URL"] = NotchiGatewayService.baseURL
                let existingKey = (env["ANTHROPIC_API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if existingKey.isEmpty {
                    env["ANTHROPIC_API_KEY"] = "eay-gateway"
                }
                current["env"] = env
            } else {
                if (env["ANTHROPIC_BASE_URL"] as? String) == NotchiGatewayService.baseURL {
                    env.removeValue(forKey: "ANTHROPIC_BASE_URL")
                }
                if (env["ANTHROPIC_API_KEY"] as? String) == "eay-gateway" {
                    env.removeValue(forKey: "ANTHROPIC_API_KEY")
                }
                if env.isEmpty {
                    current.removeValue(forKey: "env")
                } else {
                    current["env"] = env
                }
            }

            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            if let raw {
                try raw.write(to: claudeDir.appendingPathComponent("settings.json.gateway.bak"), options: .atomic)
            }
            var out = try JSONSerialization.data(withJSONObject: current, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            out.append(UInt8(ascii: "\n"))
            try out.write(to: claudeSettingsURL, options: .atomic)

            refreshClaudeStatus()
            claudeStatus = (true, enable ? "Saved! Restart Claude Code to use Notchi Gateway." : "Restored default Claude Code endpoint.")
        } catch {
            claudeStatus = (false, error.localizedDescription)
        }
    }
}
