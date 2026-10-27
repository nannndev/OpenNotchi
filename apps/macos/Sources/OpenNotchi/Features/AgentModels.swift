import AppKit

enum AgentTool: String, Codable, CaseIterable, Identifiable {
    case claude, codex, antigravity, commandcode

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .antigravity: return "Antigravity"
        case .commandcode: return "Command Code"
        }
    }
    var icon: String {
        switch self {
        case .claude: return "terminal.fill"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .antigravity: return "sparkles"
        case .commandcode: return "bolt.fill"
        }
    }

    /// The provider's real logo, bundled from 9router's provider icons (Resources/ProviderIcons).
    var logo: NSImage? { Self.logos[self] ?? nil }

    private static let logos: [AgentTool: NSImage?] = Dictionary(
        uniqueKeysWithValues: allCases.map { tool in
            (
                tool,
                Bundle.main.url(forResource: tool.rawValue, withExtension: "png", subdirectory: "ProviderIcons")
                    .flatMap(NSImage.init(contentsOf:))
            )
        })
}

enum AgentState: String {
    case working
    case needsYou = "needs_you"
    case done, idle

    var label: String { self == .needsYou ? "needs you" : rawValue }

    /// The Notchi that stands in for a session in this state.
    var mood: NotchiMood {
        switch self {
        case .working: return .busy
        case .needsYou: return .alert
        case .done: return .happy
        case .idle: return .sleepy
        }
    }
}

struct AgentSession: Identifiable, Equatable {
    var tool: AgentTool
    var id: String
    var project: String
    var state: AgentState
    var updatedAt: Date
    var message: String?
    /// Full working directory, when the log or hook reported one; `project` is its last component.
    var cwd = ""
}

/// A Claude Code, Codex, Antigravity, or 9router connection to read usage (and agent status) from.
struct AIAccount: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var tool: AgentTool
    var dir: String
    var connectionId: String? = nil
    var email: String? = nil
    var priority: Int? = nil
    var isActive: Bool = true

    private enum CodingKeys: String, CodingKey {
        case name, tool, dir, connectionId, email, priority, isActive
    }

    init(
        id: UUID = UUID(), name: String, tool: AgentTool, dir: String, connectionId: String? = nil,
        email: String? = nil, priority: Int? = nil, isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.tool = tool
        self.dir = dir
        self.connectionId = connectionId
        self.email = email
        self.priority = priority
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.tool = try container.decode(AgentTool.self, forKey: .tool)
        self.dir = try container.decode(String.self, forKey: .dir)
        self.connectionId = try container.decodeIfPresent(String.self, forKey: .connectionId)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    var url: URL { expandPath(dir) }

    /// Defaults: checks ~/.claude, ~/.gemini/antigravity-ide, ~/.codex
    static var defaults: [AIAccount] {
        let all = [
            AIAccount(name: "Claude Code", tool: .claude, dir: "~/.claude"),
            AIAccount(name: "Antigravity", tool: .antigravity, dir: "~/.gemini/antigravity-ide"),
            AIAccount(name: "Codex", tool: .codex, dir: "~/.codex"),
        ]
        let existing = all.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        return existing.isEmpty ? all : existing
    }
}
