import AppKit
import Foundation
import PDFKit

/// Ask AI conversations, kept in ~/Library/Application Support/OpenNotchi/chats.json (newest first).
@MainActor
final class ChatStore: ObservableObject {
    struct Session: Codable, Identifiable, Equatable {
        var id = UUID()
        var title: String
        var updatedAt: Date
        var messages: [AIAssistant.Message]
    }

    static let shared = ChatStore()
    /// Keeps the file small; older sessions drop off the end.
    private static let maxSessions = 50

    @Published private(set) var sessions: [Session] = []
    @Published var currentID: UUID?

    private let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenNotchi")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chats.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = saved
        }
        currentID = sessions.first?.id
    }

    var current: Session? { sessions.first { $0.id == currentID } }

    func newSession() { currentID = nil }

    /// Appends to the current session (creating one titled after the first prompt) and moves it to the top.
    func append(_ message: AIAssistant.Message) {
        if let i = sessions.firstIndex(where: { $0.id == currentID }) {
            var s = sessions.remove(at: i)
            s.messages.append(message)
            s.updatedAt = .now
            sessions.insert(s, at: 0)
        } else {
            let title = String(message.content.split(separator: "\n").first ?? "New chat").prefix(48)
            let s = Session(title: String(title), updatedAt: .now, messages: [message])
            sessions.insert(s, at: 0)
            currentID = s.id
        }
        sessions = Array(sessions.prefix(Self.maxSessions))
        save()
    }

    /// Replaces the text of the last message in the current session (used while an answer streams in).
    func updateLast(_ content: String, persist: Bool = false) {
        guard let i = sessions.firstIndex(where: { $0.id == currentID }), !sessions[i].messages.isEmpty else { return }
        sessions[i].messages[sessions[i].messages.count - 1].content = content
        if persist { save() }
    }

    /// Drops the last message of the current session (a failed or cancelled answer, before a retry).
    func removeLast() {
        guard let i = sessions.firstIndex(where: { $0.id == currentID }), !sessions[i].messages.isEmpty else { return }
        sessions[i].messages.removeLast()
        if sessions[i].messages.isEmpty {
            sessions.remove(at: i)
            currentID = nil
        }
        save()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if currentID == id { currentID = sessions.first?.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

/// Turns images, files and screenshots into things a chat message can carry.
enum ChatAttachment {
    /// Downscaled JPEG as base64; small enough to keep in the chat history file.
    static func jpegBase64(_ image: NSImage, maxSide: CGFloat = 1280) -> String? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let scale = min(1, maxSide / CGFloat(max(cg.width, cg.height)))
        let size = NSSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSImage(cgImage: cg, size: size).draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75])?.base64EncodedString()
    }

    enum Loaded {
        case image(String)
        case text(name: String, body: String)
    }

    /// An image file becomes an image; PDFs and text-like files become text (capped so one file can't flood the prompt).
    static func load(_ url: URL) -> Loaded? {
        if let image = NSImage(contentsOf: url), url.pathExtension.lowercased() != "pdf", let b64 = jpegBase64(image) {
            return .image(b64)
        }
        let body: String?
        if url.pathExtension.lowercased() == "pdf" {
            body = PDFDocument(url: url)?.string
        } else {
            body = try? String(contentsOf: url, encoding: .utf8)
        }
        guard let body, !body.isEmpty else { return nil }
        return .text(name: url.lastPathComponent, body: String(body.prefix(20_000)))
    }

    /// Lets the user drag a region (Space switches to a window); nil if they press Esc.
    static func screenshot() async -> String? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("notchi-shot-\(UUID().uuidString).png")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-i", "-x", file.path]
        do { try p.run() } catch { return nil }
        await withCheckedContinuation { c in p.terminationHandler = { _ in c.resume() } }
        defer { try? FileManager.default.removeItem(at: file) }
        return NSImage(contentsOf: file).flatMap { jpegBase64($0) }
    }
}
