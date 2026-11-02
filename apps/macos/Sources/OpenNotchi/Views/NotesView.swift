import AppKit
import SwiftUI

/// Notes list and editor on the left; keep-awake and Apple Shortcuts on the right.
struct NotesView: View {
    @ObservedObject private var store = NoteStore.shared
    @ObservedObject private var keepAwake = KeepAwake.shared
    @Environment(\.notchAccent) private var accent
    @State private var shortcuts: [String] = []
    @State private var query = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        HStack(spacing: NotchLayout.columnSpacing) {
            HStack(spacing: 8) {
                noteList.frame(width: 170)
                editor
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

    private var noteList: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("Search", text: $query).textFieldStyle(.plain).font(.system(size: 11))
                }
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.06)))
                Button {
                    query = ""
                    store.create()
                    editorFocused = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("New note")
            }

            let notes = store.search(query)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(notes) { note in row(note) }
                }
            }
            .overlay {
                if notes.isEmpty {
                    Text(query.isEmpty ? "No notes yet" : "No matches")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func row(_ note: NoteStore.Note) -> some View {
        let selected = note.id == store.currentID
        return Button {
            store.currentID = note.id
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.orange)
                    }
                    Text(note.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(note.updatedAt, format: Calendar.current.isDateInToday(note.updatedAt)
                        ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated))
                    Text(note.preview).lineLimit(1)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? accent.highlight.opacity(0.35) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(note.pinned ? "Unpin" : "Pin") { store.togglePin(note.id) }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { store.delete(note.id) }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let note = store.current {
            TextEditor(text: Binding(get: { note.text }, set: { store.update(note.id, text: $0) }))
                .font(.system(size: 12.5, design: .rounded))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                .overlay(alignment: .topLeading) {
                    if note.text.isEmpty {
                        Text("Title on the first line…")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 10) {
                        Text("\(note.text.split { $0.isWhitespace || $0.isNewline }.count) words")
                        Button { store.togglePin(note.id) } label: {
                            Image(systemName: note.pinned ? "pin.fill" : "pin")
                        }
                        .help(note.pinned ? "Unpin" : "Pin")
                        Button { store.delete(note.id) } label: { Image(systemName: "trash") }
                            .help("Delete note")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(8)
                }
        } else {
            Button {
                store.create()
                editorFocused = true
            } label: {
                Label("New note", systemImage: "square.and.pencil")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
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
