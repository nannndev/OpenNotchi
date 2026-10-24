import SwiftUI

/// Settings › AI: master toggle, Agents, Usage accounts and the Ask AI provider.
struct AISettingsPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor
    @EnvironmentObject private var usage: AIUsageManager
    @State private var hooksInstalled = false
    @State private var hookMessage: String?

    private var hookDir: AIAccount {
        settings.aiAccounts.first { $0.tool == .claude } ?? AIAccount(name: "Claude Code", tool: .claude, dir: "~/.claude")
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI features", isOn: $settings.aiEnabled)
                Text("Agent status and usage are read from files on this computer. Ask AI sends your text only to the provider you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                if NineRouterService.shared.isAvailable {
                    Section {
                        HStack(spacing: 8) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("9router Integration Active")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Detected \(usage.reports.filter(\.isFrom9Router).count) accounts across providers")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Resync") {
                                usage.refresh(force: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } header: {
                        Text("9router Multi-Account Sync")
                    } footer: {
                        Text("OpenNotchi automatically reads and monitors all multiple accounts, rate limit reset times, and real-time token quotas directly from your 9router daemon and database.")
                    }
                }

                Section("Agents") {
                    Toggle("Show Claude Code and Codex sessions", isOn: $settings.aiAgents)
                    LabeledContent {
                        if hooksInstalled {
                            Button("Remove") { setHooks(false) }
                        } else {
                            Button("Install Claude Code hooks") { setHooks(true) }
                        }
                    } label: {
                        Text("Claude Code hooks")
                        Text("Optional. Instant updates and \"needs you\" when Claude Code waits for permission. Adds a curl call to 127.0.0.1:47823 in \(hookDir.dir)/settings.json.")
                    }
                    if let hookMessage {
                        Text(hookMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    if let problem = agents.hookProblem {
                        Label(problem, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                    }
                    Toggle("Notify when an agent finishes", isOn: $settings.aiNotify)
                }

                Section {
                    ForEach($settings.aiAccounts) { $account in
                        HStack {
                            TextField("Name", text: $account.name).frame(width: 130)
                            Picker("", selection: $account.tool) {
                                ForEach(AgentTool.allCases) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            TextField("Folder", text: $account.dir)
                            Button {
                                settings.aiAccounts.removeAll { $0.id == account.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove account")
                            .accessibilityLabel("Remove account")
                        }
                        .labelsHidden()
                    }
                    HStack(spacing: 8) {
                        Button {
                            settings.aiAccounts.append(AIAccount(name: "Claude Code", tool: .claude, dir: "~/.claude"))
                        } label: {
                            Label("Add Claude", systemImage: "plus")
                        }
                        Button {
                            settings.aiAccounts.append(AIAccount(name: "Antigravity", tool: .antigravity, dir: "~/.gemini/antigravity-ide"))
                        } label: {
                            Label("Add Antigravity", systemImage: "plus")
                        }
                        Button {
                            settings.aiAccounts.append(AIAccount(name: "Codex", tool: .codex, dir: "~/.codex"))
                        } label: {
                            Label("Add Codex", systemImage: "plus")
                        }
                    }
                    Toggle("Show usage in the closed notch", isOn: $settings.aiClosedMeter)
                } header: {
                    Text("Quota & Accounts")
                } footer: {
                    if NineRouterService.shared.isAvailable {
                        Text("Usage comes from 9router for every tool it routes, so these folders aren't counted twice. They still power the Agents list, and add usage for tools 9router doesn't cover.")
                    } else {
                        Text("Folders to read sessions and usage from. Add one per account (e.g. a second CLAUDE_CONFIG_DIR).")
                    }
                }

                Section("Ask AI") {
                    ProviderSettings()
                }
            }
            .disabled(!settings.aiEnabled)
        }
        .onAppear { hooksInstalled = ClaudeHooks.isInstalled(dir: hookDir.url) }
        .onChange(of: hookDir) { _, dir in hooksInstalled = ClaudeHooks.isInstalled(dir: dir.url) }
    }

    private func setHooks(_ install: Bool) {
        do {
            try ClaudeHooks.apply(dir: hookDir.url, install: install)
            hooksInstalled = ClaudeHooks.isInstalled(dir: hookDir.url)
            hookMessage = install
                ? "Added to \(hookDir.dir)/settings.json (backup in settings.json.bak). New Claude Code sessions use them."
                : "Removed."
        } catch {
            hookMessage = error.localizedDescription
        }
    }
}

private struct ProviderSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var key = ""
    @State private var hasKey = false
    @State private var test: (ok: Bool, text: String)?
    @State private var testing = false

    private var provider: AIProvider { settings.aiProvider }

    var body: some View {
        Picker("Provider", selection: $settings.aiProvider) {
            ForEach(AIProvider.available) { Text($0.displayName).tag($0) }
        }
        switch provider {
        case .apple:
            Text("Runs on this Mac. Nothing leaves your computer.").font(.caption).foregroundStyle(.secondary)
        case .ollama:
            TextField("Base URL", text: $settings.aiOllamaURL)
            TextField("Model", text: $settings.aiOllamaModel)
        case .anthropic:
            Picker("Model", selection: $settings.aiAnthropicModel) {
                ForEach(AIAssistant.anthropicModels, id: \.self) { Text($0).tag($0) }
            }
        case .openai:
            TextField("Base URL", text: $settings.aiOpenaiURL)
            TextField("Model", text: $settings.aiOpenaiModel)
        }
        if provider.needsKey {
            LabeledContent {
                HStack {
                    SecureField(hasKey ? "•••••••• saved" : "Paste your key", text: $key)
                        .onSubmit(saveKey)
                    Button("Save", action: saveKey).disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                    if hasKey {
                        Button {
                            key = ""
                            saveKey()
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Delete key")
                            .accessibilityLabel("Delete key")
                    }
                }
            } label: {
                Text("API key")
                Text("Stored in the Keychain, never in OpenNotchi's settings.")
            }
        }
        LabeledContent {
            Button("Test", action: runTest).disabled(testing)
        } label: {
            if testing {
                Text("Testing…")
            } else if let test {
                Text(test.ok ? "Works: \"\(test.text.prefix(60))\"" : test.text).foregroundStyle(test.ok ? .green : .orange)
            } else {
                Text("Sends a one-word test prompt.").foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: loadKey)
        .onChange(of: provider) { _, _ in loadKey() }
    }

    private func loadKey() {
        key = ""
        test = nil
        hasKey = provider.needsKey && AIKeychain.get(provider) != nil
    }

    private func saveKey() {
        if AIKeychain.set(key, for: provider) {
            hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            key = ""
        } else {
            test = (false, "Couldn't save the key to the Keychain.")
        }
    }

    private func runTest() {
        testing = true
        test = nil
        Task { @MainActor in
            do {
                test = (true, try await AIAssistant.ask("Reply with the single word: ready", settings: settings))
            } catch {
                test = (false, error.localizedDescription)
            }
            testing = false
        }
    }
}
