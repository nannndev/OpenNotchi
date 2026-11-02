import Foundation

/// Notes, kept in ~/Library/Application Support/OpenNotchi/notes.json.
/// Pinned first, then most recently edited.
@MainActor
final class NoteStore: ObservableObject {
    struct Note: Codable, Identifiable, Equatable {
        var id = UUID()
        var text: String
        var pinned = false
        var updatedAt = Date()

        /// First non-empty line, without markdown heading/list marks.
        var title: String {
            let line = text.split(separator: "\n").lazy.map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
            let clean = (line ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "#-*☐☑ "))
            return clean.isEmpty ? "New note" : String(clean.prefix(60))
        }

        /// Second non-empty line onward, for the list subtitle.
        var preview: String {
            text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                .dropFirst().joined(separator: " ")
        }
    }

    static let shared = NoteStore()

    @Published private(set) var notes: [Note] = []
    @Published var currentID: UUID?

    private let file: URL

    init(file: URL? = nil, legacyText: String? = nil) {
        self.file =
            file
            ?? {
                let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("OpenNotchi")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir.appendingPathComponent("notes.json")
            }()
        if let data = try? Data(contentsOf: self.file), let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = saved
        } else if let data = try? Data(contentsOf: self.file), !data.isEmpty {
            // Unreadable file: keep a copy rather than overwrite it on the next save.
            try? data.write(to: self.file.appendingPathExtension("bak"))
        } else {
            // First run: bring over the old single scratchpad.
            let legacy = legacyText ?? UserDefaults.standard.string(forKey: "notesText") ?? ""
            if !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notes = [Note(text: legacy)]
                save()
            }
        }
        currentID = sorted.first?.id
    }

    var sorted: [Note] {
        notes.sorted { ($0.pinned ? 1 : 0, $0.updatedAt) > ($1.pinned ? 1 : 0, $1.updatedAt) }
    }

    func search(_ query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? sorted : sorted.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var current: Note? { notes.first { $0.id == currentID } }

    /// Reuses an empty note instead of piling up blank ones.
    @discardableResult
    func create() -> UUID {
        if let empty = notes.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            currentID = empty.id
            return empty.id
        }
        let note = Note(text: "")
        notes.append(note)
        currentID = note.id
        save()
        return note.id
    }

    func update(_ id: UUID, text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        notes[i].updatedAt = .now
        save()
    }

    func togglePin(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].pinned.toggle()
        save()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if currentID == id { currentID = sorted.first?.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: file, options: .atomic)
    }

    #if DEBUG
    static func selfCheck() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notes-selftest-\(UUID())")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("notes.json")

        let store = NoteStore(file: file, legacyText: "# Groceries\n- milk\n- eggs")
        assert(store.notes.count == 1 && store.current?.title == "Groceries", "old scratchpad migrated")
        assert(store.current?.preview == "- milk - eggs")
        let blank = store.create()
        assert(store.create() == blank && store.notes.count == 2, "empty note reused, not duplicated")
        store.update(blank, text: "Ideas")
        let groceries = store.notes.first { $0.title == "Groceries" }!.id
        assert(store.sorted.first?.id == blank, "most recently edited first")
        store.togglePin(groceries)
        assert(store.sorted.first?.id == groceries, "pinned first")
        assert(store.search("EGG").map(\.id) == [groceries], "case-insensitive search")

        let reopened = NoteStore(file: file, legacyText: "ignored")
        assert(reopened.notes.count == 2 && reopened.notes.contains { $0.pinned }, "saved and reloaded; no re-migration")
        reopened.delete(groceries)
        assert(reopened.notes.count == 1 && reopened.currentID == blank, "delete moves to the next note")

        try? Data("not json".utf8).write(to: file)
        assert(NoteStore(file: file, legacyText: "").notes.isEmpty)
        assert(FileManager.default.fileExists(atPath: file.path + ".bak"), "corrupt file backed up, not lost")
    }
    #endif
}
