import AppKit
import SwiftUI

struct FullCIBuildsView: View {
    @EnvironmentObject private var ciMonitor: CIBuildMonitor
    @Environment(\.notchAccent) private var accent

    @State private var isAddingRepo = false
    @State private var newRepoDraft = ""

    var body: some View {
        VStack(spacing: 6) {
            headerBar

            if !ciMonitor.localBuilds.isEmpty {
                localBuildsBanner
            }

            if ciMonitor.isLoading && ciMonitor.runs.isEmpty {
                VStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Fetching GitHub Actions for \(ciMonitor.selectedRepo)…")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = ciMonitor.lastError, ciMonitor.runs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 10, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { ciMonitor.refresh() }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ciMonitor.runs.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("No GitHub Actions workflow runs found for \(ciMonitor.selectedRepo)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(ciMonitor.runs) { run in
                            CIRunRowView(run: run)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            if isAddingRepo {
                HStack(spacing: 4) {
                    TextField("owner/repo (e.g. apple/swift)", text: $newRepoDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.1)))
                        .frame(width: 190)
                        .onSubmit { commitAddRepo() }

                    Button("Add") { commitAddRepo() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)

                    Button("Cancel") {
                        isAddingRepo = false
                        newRepoDraft = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                }
            } else {
                Menu {
                    Section("Monitored Repositories") {
                        ForEach(ciMonitor.repositories, id: \.self) { repo in
                            Button {
                                ciMonitor.selectedRepo = repo
                            } label: {
                                HStack {
                                    Text(repo)
                                    if repo == ciMonitor.selectedRepo {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        isAddingRepo = true
                    } label: {
                        Label("Add Repository (owner/repo)…", systemImage: "plus")
                    }
                    if ciMonitor.repositories.count > 1 {
                        Button(role: .destructive) {
                            ciMonitor.removeRepository(ciMonitor.selectedRepo)
                        } label: {
                            Label("Remove \(ciMonitor.selectedRepo)", systemImage: "trash")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(accent.highlight)
                        Text(ciMonitor.selectedRepo)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(.white.opacity(0.09)))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Button {
                    isAddingRepo = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .padding(4.5)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Add GitHub repository (owner/repo)")
            }

            Spacer()

            // Test CI Banner Menu
            Menu {
                Button {
                    ciMonitor.triggerSimulatedBanner(passed: true)
                } label: {
                    Label("Preview 'CI Passed' Banner", systemImage: "checkmark.seal.fill")
                }
                Button {
                    ciMonitor.triggerSimulatedBanner(passed: false)
                } label: {
                    Label("Preview 'CI Failed' Banner", systemImage: "xmark.octagon.fill")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 8.5))
                    Text("Test Banner")
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.07)))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Preview closed-notch CI completion banners")

            Button {
                ciMonitor.refresh()
                ciMonitor.scanLocalBuilds()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9.5, weight: .semibold))
                    .rotationEffect(.degrees(ciMonitor.isLoading ? 360 : 0))
                    .animation(ciMonitor.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: ciMonitor.isLoading)
                    .padding(4.5)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Refresh GitHub Actions & local builds")
        }
    }

    private var localBuildsBanner: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("Local Build Active:")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.orange)
            Text(ciMonitor.localBuilds.map { "\($0.tool) (PID \($0.pid))" }.joined(separator: " · "))
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.16)))
    }

    private func commitAddRepo() {
        let slug = newRepoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !slug.isEmpty {
            ciMonitor.addRepository(slug)
        }
        newRepoDraft = ""
        isAddingRepo = false
    }
}

private struct CIRunRowView: View {
    let run: CIWorkflowRun
    @State private var isHovered = false

    private var statusColor: Color {
        if run.isRunning { return .orange }
        if run.isSuccess { return .green }
        if run.isFailure { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 8) {
            if run.isRunning {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: run.statusIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusColor)
                    .frame(width: 14)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 5) {
                    Text(run.displayTitle)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(run.branch)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.1)))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(run.workflowName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(run.statusLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(statusColor)
                    if !run.relativeTime.isEmpty {
                        Text("· \(run.relativeTime)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            if let url = run.htmlURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 3) {
                        Text("Logs")
                            .font(.system(size: 9, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(isHovered ? 0.18 : 0.08)))
                }
                .buttonStyle(.plain)
                .help("Open workflow run on GitHub")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(isHovered ? 0.09 : 0.04))
        )
        .onHover { isHovered = $0 }
    }
}

