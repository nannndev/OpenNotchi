import SwiftUI

/// Scratchpad on the left; keep-awake and Apple Shortcuts on the right.
struct NotesView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var keepAwake = KeepAwake.shared
    @Environment(\.notchAccent) private var accent
    @State private var shortcuts: [String] = []

    var body: some View {
        HStack(spacing: NotchLayout.columnSpacing) {
            TextEditor(text: $settings.notesText)
                .font(.system(size: 12.5, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                .overlay(alignment: .topLeading) {
                    if settings.notesText.isEmpty {
                        Text("Quick notes…")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            VStack(spacing: 8) {
                Menu {
                    Button("15 minutes") { keepAwake.start(minutes: 15) }
                    Button("1 hour") { keepAwake.start(minutes: 60) }
                    Button("2 hours") { keepAwake.start(minutes: 120) }
                    Button("Until turned off") { keepAwake.start(minutes: nil) }
                    if keepAwake.isActive {
                        Divider()
                        Button("Turn off") { keepAwake.stop() }
                    }
                } label: {
                    pill(keepAwake.isActive ? awakeLabel : "Keep Awake", icon: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                         fill: keepAwake.isActive ? accent.highlight : .white.opacity(0.1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Menu {
                    if shortcuts.isEmpty {
                        Text("No shortcuts found")
                    }
                    ForEach(shortcuts, id: \.self) { name in
                        Button(name) { ShortcutsRunner.run(name) }
                    }
                } label: {
                    pill("Shortcuts", icon: "square.2.layers.3d.fill", fill: .white.opacity(0.1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .onAppear { ShortcutsRunner.list { shortcuts = $0 } }

                Spacer(minLength: 0)
            }
            .frame(width: NotchLayout.sideColumn)
        }
    }

    private var awakeLabel: String {
        guard let until = keepAwake.until, until != .distantFuture else { return "Awake ∞" }
        return "Awake · \(until.formatted(date: .omitted, time: .shortened))"
    }

    private func pill(_ title: String, icon: String, fill: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11.5, weight: .semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
    }
}

/// Lists and runs the user's Apple Shortcuts through the `shortcuts` command-line tool.
enum ShortcutsRunner {
    static func list(completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = launch(["list"])
            let names = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            DispatchQueue.main.async { completion(names) }
        }
    }

    static func run(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async { _ = launch(["run", name]) }
    }

    @discardableResult
    private static func launch(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
