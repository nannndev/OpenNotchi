import SwiftUI

struct AboutPane: View {
    @EnvironmentObject private var updater: Updater

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            (Text("Open") + Text("Notchi").foregroundColor(.secondary))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(
                "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")"
            )
            .foregroundStyle(.secondary)
            Text("Free and open source under the MIT license.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                if let update = updater.availableUpdate {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.cyan)
                        Text("Update v\(update.version) tersedia!")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }

                Button(updater.isChecking ? "Checking…" : "Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(updater.isChecking)

                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                    .toggleStyle(.checkbox)
                    .font(.callout)

                Button("Test Notch Update Banner") {
                    updater.simulateUpdateNotification()
                }
                .buttonStyle(.link)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
