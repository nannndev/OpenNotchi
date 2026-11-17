import AppKit
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
                if NotchiGatewayService.shared.isAvailable {
                    Section {
                        NotchiGatewayManagerView()
                    } header: {
                        Text("Notchi Gateway (Built-in)")
                    } footer: {
                        Text("Local multi-provider AI router, OAuth account manager, and OpenAI-compatible endpoint.")
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
                    if NotchiGatewayService.shared.isAvailable || NotchiGatewayService.shared.hasDatabase {
                        Text("Usage comes from Notchi Gateway for every tool it routes, so these folders aren't counted twice. They still power the Agents list, and add usage for tools the Gateway doesn't cover.")
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

struct ProviderSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var key = ""
    @State private var hasKey = false
    @State private var test: (ok: Bool, text: String)?
    @State private var testing = false
    @State private var routerModels: [String] = []

    private var provider: AIProvider { settings.aiProvider }

    var body: some View {
        Picker("Provider", selection: $settings.aiProvider) {
            ForEach(AIProvider.available) { Text($0.displayName).tag($0) }
        }
        switch provider {
        case .gateway:
            LabeledContent("Model") {
                SearchableDropdown(
                    options: Self.modelDropdownOptions(routerModels, autoLabel: "Automatic (auto fallback)"),
                    selectedId: settings.aiGatewayModel,
                    placeholder: "Search models…"
                ) { settings.aiGatewayModel = $0 }
            }
            .task { routerModels = await NotchiGatewayService.shared.models() }
            Text("Managed in the Notchi Gateway section above.").font(.caption).foregroundStyle(.secondary)
        case .apple:
            Text("Runs on this Mac. Nothing leaves your computer. Its safety filter can block harmless prompts.").font(.caption).foregroundStyle(.secondary)
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

    static func modelDropdownOptions(_ models: [String], autoLabel: String) -> [SearchableDropdownOption] {
        var out = [
            SearchableDropdownOption(
                id: "",
                title: autoLabel,
                subtitle: "Smart routing across active accounts",
                badgeText: "Auto",
                badgeColor: .accentColor,
                icon: AnyView(Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor).frame(width: 20, height: 20))
            )
        ]
        for m in models {
            let parts = m.split(separator: "/", maxSplits: 1).map(String.init)
            let prov = parts.count == 2 ? parts[0] : "model"
            let name = parts.count == 2 ? parts[1] : m
            out.append(SearchableDropdownOption(
                id: m,
                title: name,
                subtitle: m,
                badgeText: prov,
                badgeColor: .secondary,
                icon: AnyView(ProviderBrandIcon(providerId: prov, name: prov, size: 18))
            ))
        }
        return out
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

private struct NotchiGatewayManagerView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case providers = "Providers"
        case accounts = "Accounts"
        case routing = "Routing"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "bolt.horizontal.circle.fill"
            case .providers: return "cpu.fill"
            case .accounts: return "person.2.fill"
            case .routing: return "arrow.triangle.branch"
            }
        }
    }

    @ObservedObject private var gateway = NotchiGatewayService.shared
    var onModelsChanged: () -> Void = {}

    @State private var tab: Tab = .overview
    @State private var providers: [GatewayProviderInfo] = []
    @State private var accounts: [GatewayOAuthAccount] = []
    @State private var oauthProviders: [GatewayOAuthProviderMeta] = []
    @State private var stats: GatewayStats?

    @State private var selectedProviderId = "openai"
    @State private var apiKeyInput = ""
    @State private var baseURLInput = ""
    @State private var newModelName = ""
    @State private var selectedOAuthProvider = "claude"
    @State private var activeOAuth: GatewayOAuthStart?
    @State private var oauthCallbackInput = ""
    @State private var oauthWorking = false

    @State private var routing: GatewayRoutingState?
    @State private var combos: [String: [String]] = [:]
    @State private var newComboName = ""
    @State private var newComboTargets = ""

    @State private var copiedEndpoint = false
    @State private var busy = false
    @State private var statusMessage: (ok: Bool, text: String)?

    private var selectedProvider: GatewayProviderInfo? {
        providers.first { $0.id == selectedProviderId } ?? providers.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Tab.allCases) { item in
                    let active = tab == item
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { tab = item }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(active ? Color.accentColor.opacity(0.16) : Color.clear)
                        )
                        .foregroundStyle(active ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(gateway.isRunning ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(gateway.isRunning ? ":\(String(NotchiGatewayService.defaultPort))" : "Starting")
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }

            switch tab {
            case .overview:
                overviewTab
            case .providers:
                providersTab
            case .accounts:
                accountsTab
            case .routing:
                routingTab
            }

            if let statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: statusMessage.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(statusMessage.text)
                }
                .font(.caption)
                .foregroundStyle(statusMessage.ok ? .green : .red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((statusMessage.ok ? Color.green : Color.red).opacity(0.1))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .task { await reload() }
    }

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Local OpenAI-Compatible Endpoint")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(NotchiGatewayService.v1BaseURL)
                        .font(.system(size: 12, weight: .medium).monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(NotchiGatewayService.v1BaseURL, forType: .string)
                    withAnimation { copiedEndpoint = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation { copiedEndpoint = false }
                    }
                } label: {
                    Label(copiedEndpoint ? "Copied" : "Copy", systemImage: copiedEndpoint ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task {
                        busy = true
                        await gateway.restart()
                        await reload()
                        busy = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(busy)
                .help("Restart Notchi Gateway")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )

            if let stats {
                HStack(spacing: 8) {
                    statCard("Connected", "\(stats.connectedProviders)", icon: "link.circle.fill", tint: .green)
                    statCard("Requests", "\(stats.requests)", icon: "arrow.up.arrow.down.circle.fill", tint: .blue)
                    statCard("Tokens", formatCompact(stats.inputTokens + stats.outputTokens), icon: "sparkles", tint: .purple)
                    if stats.errors > 0 {
                        statCard("Errors", "\(stats.errors)", icon: "exclamationmark.circle.fill", tint: .red)
                    }
                }
            }

            Text("Point Claude Code, Codex, Cursor, or any OpenAI-compatible client to this URL.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var providersTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if providers.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading providers…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                let items = providers.map { p in
                    SearchableDropdownOption(
                        id: p.id,
                        title: p.name,
                        subtitle: p.family.capitalized,
                        badgeText: !p.enabled ? "Disabled" : (p.connected ? "Connected" : "No Key"),
                        badgeColor: !p.enabled ? .orange : (p.connected ? .green : .secondary),
                        icon: AnyView(ProviderBrandIcon(providerId: p.id, name: p.name, size: 20))
                    )
                }
                SearchableDropdown(
                    options: items,
                    selectedId: selectedProviderId,
                    placeholder: "Search providers…"
                ) { picked in
                    selectedProviderId = picked
                    apiKeyInput = ""
                    baseURLInput = selectedProvider?.baseUrl ?? ""
                    statusMessage = nil
                }

                if let p = selectedProvider {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ProviderBrandIcon(providerId: p.id, name: p.name, size: 26)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(p.name).font(.system(size: 12.5, weight: .semibold))
                                    statusBadge(
                                        text: !p.enabled ? "Disabled" : (p.connected ? "Connected" : "No Key"),
                                        color: !p.enabled ? .orange : (p.connected ? .green : .secondary)
                                    )
                                }
                                Text(p.family.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if p.connected && p.needsKey {
                                Button("Disconnect", role: .destructive) {
                                    Task {
                                        try? await gateway.disconnectProvider(id: p.id)
                                        await reload()
                                        onModelsChanged()
                                        statusMessage = (true, "Disconnected \(p.name).")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Toggle("", isOn: Binding(
                                get: { p.enabled },
                                set: { next in
                                    Task {
                                        try? await gateway.toggleProvider(id: p.id, enabled: next)
                                        await reload()
                                        onModelsChanged()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }

                        if p.needsKey {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    SecureField(p.connected ? "•••••••• (paste new API key)" : "Paste API key…", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                                    Button("Connect") { connectSelectedProvider(p) }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(busy || apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                                if let source = ["commandcode": "Command Code CLI", "xiaomi-mimo": "MiMo Desktop"][p.id] {
                                    Button {
                                        Task {
                                            busy = true
                                            defer { busy = false }
                                            do {
                                                try await gateway.importLocalKey(providerId: p.id)
                                                await reload()
                                                onModelsChanged()
                                                statusMessage = (true, "Imported key from \(source).")
                                            } catch {
                                                statusMessage = (false, error.localizedDescription)
                                            }
                                        }
                                    } label: {
                                        Label("Import from \(source)", systemImage: "square.and.arrow.down")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(busy)
                                }
                                TextField(p.defaultBaseUrl?.isEmpty == false ? "Custom Base URL (optional)" : "Base URL (required)", text: $baseURLInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04)))
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Models")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Spacer()
                                let customCount = p.customModels?.count ?? 0
                                Text(modelSourceText(p, customCount: customCount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if p.connected {
                                    Button {
                                        syncModels(p.id, name: p.name)
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 10.5, weight: .semibold))
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(busy)
                                    .help("Refresh models from \(p.name)")
                                }
                            }

                            HStack(spacing: 6) {
                                TextField("Add custom model (e.g. gpt-5-mini)", text: $newModelName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                                    .onSubmit { addModel(for: p.id) }
                                Button {
                                    addModel(for: p.id)
                                } label: {
                                    Label("Add", systemImage: "plus")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(newModelName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }

                            let custom = p.customModels ?? []
                            if !custom.isEmpty {
                                FlowModelChips(models: custom) { model in
                                    Task {
                                        try? await gateway.removeProviderModel(providerId: p.id, model: model)
                                        await reload()
                                        onModelsChanged()
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var accountsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                let sourceList: [(id: String, name: String)] = oauthProviders.isEmpty
                    ? [("claude", "Claude"), ("codex", "ChatGPT / Codex"), ("copilot", "GitHub Copilot"), ("gemini-cli", "Gemini CLI")]
                    : oauthProviders.map { ($0.id, $0.name) }
                let items = sourceList.map { op in
                    let count = accounts.filter { $0.provider == op.id }.count
                    return SearchableDropdownOption(
                        id: op.id,
                        title: op.name,
                        subtitle: nil,
                        badgeText: count > 0 ? "\(count) linked" : nil,
                        badgeColor: count > 0 ? .accentColor : .secondary,
                        icon: AnyView(ProviderBrandIcon(providerId: op.id, name: op.name, size: 18))
                    )
                }
                SearchableDropdown(
                    options: items,
                    selectedId: selectedOAuthProvider,
                    placeholder: "Search OAuth providers…"
                ) { picked in
                    selectedOAuthProvider = picked
                }

                Button {
                    startOAuthLogin(for: selectedOAuthProvider)
                } label: {
                    Label(oauthWorking ? "Waiting…" : "Connect", systemImage: "person.badge.plus")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(oauthWorking)

                if selectedOAuthProvider == "kiro" {
                    Button {
                        Task {
                            do {
                                try await gateway.importLocalKey(providerId: "kiro")
                                await reload()
                                onModelsChanged()
                                statusMessage = (true, "Imported login from Kiro IDE.")
                            } catch {
                                statusMessage = (false, error.localizedDescription)
                            }
                        }
                    } label: {
                        Label("Import from Kiro IDE", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(oauthWorking)
                }
            }

            if let activeOAuth {
                VStack(alignment: .leading, spacing: 8) {
                    if let code = activeOAuth.userCode, !code.isEmpty {
                        HStack(spacing: 8) {
                            Text("Device Code:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(code)
                                .font(.system(size: 13, weight: .bold).monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.14)))
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(code, forType: .string)
                            }
                            .controlSize(.small)
                            Spacer()
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for browser login…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel") {
                                self.activeOAuth = nil
                                oauthWorking = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        HStack(spacing: 6) {
                            TextField("Or paste callback URL / code manually…", text: $oauthCallbackInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                            Button("Complete") { completeOAuthLogin() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(oauthCallbackInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            if accounts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("No OAuth accounts connected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                )
            } else {
                let grouped = Dictionary(grouping: accounts, by: { $0.provider })
                let providerKeys = grouped.keys.sorted()
                VStack(spacing: 8) {
                    ForEach(providerKeys, id: \.self) { provId in
                        let provAccounts = grouped[provId] ?? []
                        let provName = oauthProviders.first { $0.id == provId }?.name ?? provId.capitalized
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 7) {
                                ProviderBrandIcon(providerId: provId, name: provName, size: 20)
                                Text(provName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(provAccounts.count)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                                Spacer()
                                if ["copilot", "kimi", "kilocode", "nous", "cline"].contains(provId) {
                                    Button {
                                        syncModels(provId, name: provName)
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 10.5, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .disabled(busy)
                                    .help("Refresh \(provName) models")
                                }
                                Button {
                                    selectedOAuthProvider = provId
                                    startOAuthLogin(for: provId)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(oauthWorking)
                                .help("Add another \(provName) account")
                            }

                            ForEach(provAccounts) { acc in
                                HStack(spacing: 8) {
                                    Toggle("", isOn: Binding(
                                        get: { acc.enabled },
                                        set: { next in
                                            Task {
                                                try? await gateway.toggleAccount(provider: acc.provider, id: acc.id, enabled: next)
                                                await reload()
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.small)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(acc.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(acc.enabled ? .primary : .secondary)
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            if let plan = acc.plan, !plan.isEmpty {
                                                statusBadge(text: plan, color: .accentColor)
                                            }
                                            if !acc.enabled {
                                                statusBadge(text: "Paused", color: .orange)
                                            }
                                            if let until = acc.coolingUntil, until > Date().timeIntervalSince1970 {
                                                statusBadge(text: "Cooling \(Int(until - Date().timeIntervalSince1970))s", color: .yellow)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if provAccounts.count > 1, let idx = provAccounts.firstIndex(where: { $0.id == acc.id }) {
                                        Text("#\(idx + 1)")
                                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        moveButtons(index: idx, count: provAccounts.count) { from, to in
                                            var ids = provAccounts.map(\.id)
                                            ids.swapAt(from, to)
                                            Task {
                                                try? await gateway.reorderAccounts(provider: provId, ids: ids)
                                                await reload()
                                            }
                                        }
                                    }
                                    Button(role: .destructive) {
                                        Task {
                                            try? await gateway.removeAccount(provider: acc.provider, id: acc.id)
                                            await reload()
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove account")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.03))
                                )
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    private var routingTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let routing {
                let st = routing.settings
                card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Strategy").font(.system(size: 11.5, weight: .semibold))
                        Picker("", selection: Binding(
                            get: { st.routingStrategy },
                            set: { v in saveRouting(["routing_strategy": v]) }
                        )) {
                            Text("Priority").tag("priority")
                            Text("Round robin").tag("round_robin")
                            Text("Fill first").tag("fill_first")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(strategyHint(st.routingStrategy)).font(.caption2).foregroundStyle(.secondary)

                        Text("Fallback order").font(.system(size: 11.5, weight: .semibold)).padding(.top, 4)
                        Picker("", selection: Binding(
                            get: { st.fallbackOrder },
                            set: { v in saveRouting(["fallback_order": v]) }
                        )) {
                            Text("Model first").tag("model_first")
                            Text("Account first").tag("account_first")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(st.fallbackOrder == "account_first"
                             ? "Tries every model on one account before moving to the next account."
                             : "Tries the best model on every account before falling back to a smaller model.")
                            .font(.caption2).foregroundStyle(.secondary)

                        HStack {
                            Stepper("Models per API-key provider: \(st.autoModelsPerProvider)",
                                    value: Binding(get: { st.autoModelsPerProvider }, set: { saveRouting(["auto_models_per_provider": $0]) }),
                                    in: 1...10)
                        }
                        .font(.system(size: 11.5))
                        .padding(.top, 4)
                        Stepper("Cooldown after rate limit: \(st.cooldownSecs == 0 ? "off" : "\(st.cooldownSecs)s")",
                                value: Binding(get: { st.cooldownSecs }, set: { saveRouting(["cooldown_secs": $0]) }),
                                in: 0...600, step: 30)
                            .font(.system(size: 11.5))
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Provider priority for `auto`").font(.system(size: 11.5, weight: .semibold))
                            Spacer()
                            if !st.providerPriority.isEmpty {
                                Button("Reset") { saveRouting(["provider_priority": [String]()]) }
                                    .buttonStyle(.borderless).font(.caption)
                            }
                        }
                        if routing.autoOrder.isEmpty {
                            Text("Connect an account or API key first.").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(Array(routing.autoOrder.enumerated()), id: \.element) { idx, pid in
                            HStack(spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                ProviderBrandIcon(providerId: pid, name: providerName(pid), size: 18)
                                Text(providerName(pid)).font(.system(size: 12, weight: .medium))
                                Text("\(providerAlias(pid))/auto")
                                    .font(.system(size: 10.5).monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                moveButtons(index: idx, count: routing.autoOrder.count) { from, to in
                                    var order = routing.autoOrder
                                    order.swapAt(from, to)
                                    saveRouting(["provider_priority": order])
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                        }
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Combos (auto mix)").font(.system(size: 11.5, weight: .semibold))
                        ForEach(combos.keys.sorted(), id: \.self) { name in
                            HStack(alignment: .top, spacing: 8) {
                                Text("auto/\(name)")
                                    .font(.system(size: 11.5, weight: .semibold).monospaced())
                                Text((combos[name] ?? []).joined(separator: " → "))
                                    .font(.system(size: 10.5).monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .onTapGesture {
                                        newComboName = name
                                        newComboTargets = (combos[name] ?? []).joined(separator: ", ")
                                    }
                                Spacer()
                                Button(role: .destructive) {
                                    Task {
                                        try? await gateway.deleteCombo(name: name)
                                        await reload()
                                        onModelsChanged()
                                    }
                                } label: { Image(systemName: "trash").font(.system(size: 11)) }
                                .buttonStyle(.borderless)
                            }
                        }
                        HStack(spacing: 6) {
                            TextField("name", text: $newComboName)
                                .textFieldStyle(.plain)
                                .frame(width: 90)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                            TextField("cx/gpt-5.5, cc/auto, ds/deepseek-chat", text: $newComboTargets)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                                .onSubmit { saveCombo() }
                            Button("Save") { saveCombo() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(newComboName.trimmingCharacters(in: .whitespaces).isEmpty
                                          || newComboTargets.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.system(size: 11.5))
                        Text("Tried in order; each entry can be a model or `<alias>/auto`. Click a combo to edit it.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Text("Model ids: `auto` (all providers by priority) · `<alias>/auto` (one provider) · `auto/<combo>` (your mix).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading routing…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func modelSourceText(_ p: GatewayProviderInfo, customCount: Int) -> String {
        guard let synced = p.syncedCount, synced > 0, let at = p.modelsSyncedAt else {
            return "\(p.seedModels?.count ?? 0) built-in · \(customCount) custom"
        }
        let ago = RelativeDateTimeFormatter().localizedString(for: Date(timeIntervalSince1970: at), relativeTo: Date())
        return "\(synced) from provider · \(customCount) custom · synced \(ago)"
    }

    private func syncModels(_ providerId: String, name: String) {
        Task {
            busy = true
            defer { busy = false }
            do {
                let n = try await gateway.syncProviderModels(providerId: providerId)
                await reload()
                onModelsChanged()
                statusMessage = (true, "Fetched \(n) models from \(name).")
            } catch {
                statusMessage = (false, "\(name): \(error.localizedDescription)")
            }
        }
    }

    private func strategyHint(_ s: String) -> String {
        switch s {
        case "round_robin": return "Spreads requests across a provider's accounts in turn."
        case "fill_first": return "Keeps using the account that last worked until it fails or hits a limit."
        default: return "Always starts with your first account and falls back in order."
        }
    }

    private func providerName(_ id: String) -> String {
        oauthProviders.first { $0.id == id }?.name ?? providers.first { $0.id == id }?.name ?? id
    }

    private func providerAlias(_ id: String) -> String {
        oauthProviders.first { $0.id == id }?.alias ?? providers.first { $0.id == id }?.alias ?? id
    }

    private func moveButtons(index: Int, count: Int, swap: @escaping (Int, Int) -> Void) -> some View {
        HStack(spacing: 2) {
            Button { swap(index, index - 1) } label: { Image(systemName: "chevron.up").font(.system(size: 10, weight: .semibold)) }
                .disabled(index == 0)
                .help("Move up")
            Button { swap(index, index + 1) } label: { Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)) }
                .disabled(index >= count - 1)
                .help("Move down")
        }
        .buttonStyle(.borderless)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
            )
    }

    private func saveRouting(_ fields: [String: Any]) {
        Task {
            do {
                try await gateway.updateRouting(fields)
                routing = await gateway.fetchRouting()
                onModelsChanged()
            } catch {
                statusMessage = (false, error.localizedDescription)
            }
        }
    }

    private func saveCombo() {
        let name = newComboName.trimmingCharacters(in: .whitespaces)
        let targets = newComboTargets.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            do {
                try await gateway.saveCombo(name: name, targets: targets)
                newComboName = ""
                newComboTargets = ""
                await reload()
                onModelsChanged()
                statusMessage = (true, "Saved combo auto/\(name).")
            } catch {
                statusMessage = (false, error.localizedDescription)
            }
        }
    }

    private func statCard(_ label: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10.5))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func reload() async {
        providers = await gateway.fetchProviders()
        if let first = providers.first, !providers.contains(where: { $0.id == selectedProviderId }) {
            selectedProviderId = first.id
        }
        if baseURLInput.isEmpty {
            baseURLInput = selectedProvider?.baseUrl ?? ""
        }
        if let accState = await gateway.fetchAccountsState() {
            accounts = accState.accounts
            if let ops = accState.providers, !ops.isEmpty {
                oauthProviders = ops
                if !ops.contains(where: { $0.id == selectedOAuthProvider }), let first = ops.first {
                    selectedOAuthProvider = first.id
                }
            }
        }
        stats = await gateway.fetchStats()
        routing = await gateway.fetchRouting()
        combos = await gateway.fetchCombos()
    }

    private func connectSelectedProvider(_ provider: GatewayProviderInfo) {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        busy = true
        statusMessage = nil
        Task {
            do {
                try await gateway.connectProvider(id: provider.id, apiKey: key, baseUrl: baseURLInput)
                apiKeyInput = ""
                await reload()
                onModelsChanged()
                statusMessage = (true, "Connected \(provider.name).")
            } catch {
                statusMessage = (false, error.localizedDescription)
            }
            busy = false
        }
    }

    private func addModel(for providerId: String) {
        let model = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return }
        newModelName = ""
        statusMessage = nil
        Task {
            do {
                try await gateway.addProviderModel(providerId: providerId, model: model)
                await reload()
                onModelsChanged()
            } catch {
                statusMessage = (false, error.localizedDescription)
            }
        }
    }

    private func startOAuthLogin(for prov: String) {
        oauthWorking = true
        statusMessage = nil
        let previousIds = Set(accounts.map(\.id))
        Task {
            do {
                let flow = try await gateway.startOAuth(provider: prov)
                activeOAuth = flow
                if let urlStr = flow.authUrl, let url = URL(string: urlStr) {
                    NSWorkspace.shared.open(url)
                }
                if flow.userCode != nil || flow.flow == "device" {
                    for _ in 0..<40 {
                        try? await Task.sleep(nanoseconds: UInt64(flow.intervalSeconds) * 1_000_000_000)
                        let status = try await gateway.pollOAuth(provider: prov, sessionId: flow.sessionId)
                        if status == "done" {
                            activeOAuth = nil
                            oauthWorking = false
                            await reload()
                            onModelsChanged()
                            statusMessage = (true, "Account connected.")
                            return
                        }
                    }
                    oauthWorking = false
                } else {
                    // PKCE localhost callback completes in the background; poll accounts until a new/updated one arrives.
                    for _ in 0..<60 {
                        if activeOAuth == nil { return }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if let accState = await gateway.fetchAccountsState(),
                           accState.accounts.contains(where: { $0.provider == prov && !previousIds.contains($0.id) }) {
                            activeOAuth = nil
                            oauthWorking = false
                            await reload()
                            onModelsChanged()
                            statusMessage = (true, "Account connected.")
                            return
                        }
                    }
                    oauthWorking = false
                }
            } catch {
                oauthWorking = false
                statusMessage = (false, error.localizedDescription)
            }
        }
    }

    private func completeOAuthLogin() {
        guard let flow = activeOAuth else { return }
        let callback = oauthCallbackInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !callback.isEmpty else { return }
        let prov = selectedOAuthProvider
        Task {
            do {
                try await gateway.completeOAuth(provider: prov, sessionId: flow.sessionId, callback: callback)
                oauthCallbackInput = ""
                activeOAuth = nil
                oauthWorking = false
                await reload()
                onModelsChanged()
                statusMessage = (true, "Account connected.")
            } catch {
                oauthWorking = false
                statusMessage = (false, error.localizedDescription)
            }
        }
    }
}

private struct ProviderBrandIcon: View {
    let providerId: String
    let name: String
    var size: CGFloat = 22

    private static func rawAsset(for providerId: String) -> NSImage? {
        let key: String? = switch providerId.lowercased() {
        case "claude", "anthropic": "claude"
        case "codex": "codex"
        case "antigravity": "antigravity"
        case "commandcode": "commandcode"
        default: nil
        }
        guard let key else { return nil }
        return Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "ProviderIcons")
            .flatMap(NSImage.init(contentsOf:))
    }

    private static func resized(_ source: NSImage, to size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let img = NSImage(size: target)
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: target),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy,
                    fraction: 1.0)
        img.unlockFocus()
        return img
    }

    /// Fixed-size image safe to use inside macOS `Menu` labels & items (which ignore SwiftUI `.frame`).
    @ViewBuilder
    static func menuIcon(providerId: String, size: CGFloat = 16) -> some View {
        if let raw = rawAsset(for: providerId) {
            Image(nsImage: resized(raw, to: size))
        } else {
            Image(systemName: style(for: providerId).symbol)
        }
    }

    private static func style(for providerId: String) -> (symbol: String, color: Color) {
        switch providerId.lowercased() {
        case "openai", "codex", "oai", "cx": return ("sparkles", Color(red: 0.06, green: 0.64, blue: 0.49))
        case "anthropic", "claude", "ant", "cc": return ("brain.head.profile", Color(red: 0.85, green: 0.47, blue: 0.34))
        case "gemini", "gemini-cli", "google", "gem", "gc": return ("diamond.fill", Color(red: 0.26, green: 0.52, blue: 0.96))
        case "copilot", "github", "gh": return ("chevron.left.forwardslash.chevron.right", Color(red: 0.44, green: 0.32, blue: 0.85))
        case "deepseek", "ds": return ("waveform.path.ecg", Color(red: 0.25, green: 0.42, blue: 0.92))
        case "openrouter", "or": return ("arrow.triangle.branch", Color(red: 0.38, green: 0.40, blue: 0.95))
        case "groq": return ("bolt.fill", Color(red: 0.94, green: 0.34, blue: 0.22))
        case "mistral": return ("wind", Color(red: 0.96, green: 0.52, blue: 0.14))
        case "together": return ("square.stack.3d.up.fill", Color(red: 0.18, green: 0.49, blue: 0.96))
        case "xai", "grok": return ("xmark", Color(white: 0.25))
        case "cohere": return ("circle.grid.2x2.fill", Color(red: 0.22, green: 0.58, blue: 0.46))
        case "fireworks": return ("flame.fill", Color(red: 0.90, green: 0.30, blue: 0.28))
        case "perplexity": return ("magnifyingglass.circle.fill", Color(red: 0.13, green: 0.62, blue: 0.68))
        case "cerebras": return ("cpu.fill", Color(red: 0.88, green: 0.38, blue: 0.18))
        case "hyperbolic": return ("infinity", Color(red: 0.48, green: 0.32, blue: 0.88))
        case "sambanova": return ("atom", Color(red: 0.92, green: 0.42, blue: 0.22))
        case "novita": return ("wand.and.stars", Color(red: 0.52, green: 0.36, blue: 0.92))
        case "siliconflow": return ("memorychip.fill", Color(red: 0.34, green: 0.44, blue: 0.90))
        case "ollama": return ("desktopcomputer", Color(white: 0.42))
        case "azure-openai": return ("cloud.fill", Color(red: 0.00, green: 0.47, blue: 0.83))
        case "aws-bedrock": return ("cube.fill", Color(red: 0.92, green: 0.55, blue: 0.12))
        case "moonshot", "kimi": return ("moon.stars.fill", Color(red: 0.22, green: 0.32, blue: 0.72))
        case "dashscope", "qwen": return ("sparkles.rectangle.stack.fill", Color(red: 0.42, green: 0.28, blue: 0.88))
        case "zai", "glm": return ("z.circle.fill", Color(red: 0.16, green: 0.52, blue: 0.88))
        case "minimax": return ("waveform", Color(red: 0.86, green: 0.28, blue: 0.48))
        case "nvidia": return ("rectangle.3.group.fill", Color(red: 0.46, green: 0.73, blue: 0.00))
        case "deepinfra": return ("server.rack", Color(red: 0.24, green: 0.48, blue: 0.82))
        case "muse": return ("paintpalette.fill", Color(red: 0.12, green: 0.48, blue: 0.92))
        case "nous": return ("compass.drawing", Color(red: 0.58, green: 0.38, blue: 0.86))
        case "kilocode": return ("terminal.fill", Color(red: 0.82, green: 0.36, blue: 0.24))
        case "custom": return ("slider.horizontal.3", Color(white: 0.45))
        default: return ("cpu.fill", .accentColor)
        }
    }

    var body: some View {
        if let raw = Self.rawAsset(for: providerId) {
            Image(nsImage: Self.resized(raw, to: size))
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
        } else {
            let s = Self.style(for: providerId)
            Image(systemName: s.symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.26)
                        .fill(s.color.gradient)
                )
        }
    }
}

private struct DropdownOption: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let badgeText: String?
    let badgeColor: Color
}

private struct SearchableProviderDropdown: View {
    let options: [DropdownOption]
    let selectedId: String
    var placeholder: String = "Search…"
    let onSelect: (String) -> Void

    @State private var open = false
    @State private var query = ""
    @State private var hoveredId: String?

    private var current: DropdownOption? {
        options.first { $0.id == selectedId } ?? options.first
    }

    private var filtered: [DropdownOption] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return options }
        return options.filter {
            $0.name.lowercased().contains(q)
                || $0.id.lowercased().contains(q)
                || ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        Button {
            query = ""
            open.toggle()
        } label: {
            HStack(spacing: 8) {
                if let cur = current {
                    ProviderBrandIcon(providerId: cur.id, name: cur.name, size: 20)
                    Text(cur.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if let badge = cur.badgeText {
                        Text(badge)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(cur.badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(cur.badgeColor.opacity(0.14)))
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(placeholder, text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))

                Divider()

                ScrollView {
                    LazyVStack(spacing: 2) {
                        if filtered.isEmpty {
                            Text("No matching providers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(filtered) { item in
                                let isSelected = item.id == selectedId
                                let isHovered = hoveredId == item.id
                                Button {
                                    onSelect(item.id)
                                    open = false
                                } label: {
                                    HStack(spacing: 8) {
                                        ProviderBrandIcon(providerId: item.id, name: item.name, size: 20)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name)
                                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                                .lineLimit(1)
                                            if let sub = item.subtitle, !sub.isEmpty {
                                                Text(sub)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if let badge = item.badgeText {
                                            Text(badge)
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundStyle(item.badgeColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(item.badgeColor.opacity(0.14)))
                                        }
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10.5, weight: .bold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    hoveredId = hovering ? item.id : (hoveredId == item.id ? nil : hoveredId)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 280)
            }
            .frame(width: 310)
        }
    }
}

private struct FlowModelChips: View {
    let models: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(models, id: \.self) { m in
                    HStack(spacing: 4) {
                        Text(m)
                            .font(.system(size: 11, weight: .medium).monospaced())
                        Button { onRemove(m) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    )
                }
            }
        }
    }
}
