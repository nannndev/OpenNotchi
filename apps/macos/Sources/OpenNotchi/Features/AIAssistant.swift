import Foundation
import Security
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case apple, ollama, anthropic, openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple Intelligence (on-device)"
        case .ollama: return "Ollama (local)"
        case .anthropic: return "Anthropic API"
        case .openai: return "OpenAI-compatible"
        }
    }

    var needsKey: Bool { self == .anthropic || self == .openai }

    /// Providers to offer: Apple Intelligence only when the on-device model is ready.
    static var available: [AIProvider] { AIAssistant.appleAvailable ? allCases : allCases.filter { $0 != .apple } }
}

/// API keys in the login Keychain, never in UserDefaults.
enum AIKeychain {
    private static let service = "io.github.opennotchi.ai"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func get(_ provider: AIProvider) -> String? {
        var q = query(provider.rawValue)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the key, or deletes it when empty.
    @discardableResult
    static func set(_ key: String, for provider: AIProvider) -> Bool {
        let q = query(provider.rawValue)
        SecItemDelete(q as CFDictionary)
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return true }
        var add = q
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}

enum QuickAction: String, CaseIterable, Identifiable {
    case summarize, fix, translate, explain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summarize: return "Summarize"
        case .fix: return "Fix writing"
        case .translate: return "Translate"
        case .explain: return "Explain lyric"
        }
    }

    var icon: String {
        switch self {
        case .summarize: return "text.append"
        case .fix: return "wand.and.stars"
        case .translate: return "character.bubble"
        case .explain: return "music.note"
        }
    }

    func prompt(_ text: String, song: (title: String, artist: String)? = nil) -> String {
        switch self {
        case .summarize: return "Summarize this in a few sentences:\n\n\(text)"
        case .fix: return "Fix the spelling, grammar and wording of this text. Reply with the corrected text only:\n\n\(text)"
        case .translate:
            let language = Locale(identifier: "en").localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English"
            return "Translate this into \(language). Reply with the translation only:\n\n\(text)"
        case .explain:
            let from = song.map { " from \"\($0.title)\" by \($0.artist)" } ?? ""
            return "Explain the meaning of this song lyric\(from):\n\n\"\(text)\""
        }
    }
}

/// Sends one prompt to the provider chosen in Settings › AI. The only AI code that uses the network.
enum AIAssistant {
    static let systemPrompt = "You answer inside a small panel at the top of the user's screen. Be concise. Reply in plain text, no markdown headings."
    static let anthropicModels = ["claude-haiku-5-5", "claude-sonnet-5-5"]

    static var appleAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { return SystemLanguageModel.default.availability == .available }
        #endif
        return false
    }

    static func ask(_ prompt: String, settings: AppSettings = .shared) async throws -> String {
        let provider = settings.aiProvider
        switch provider {
        case .apple:
            #if canImport(FoundationModels)
            if #available(macOS 26, *), appleAvailable {
                let session = LanguageModelSession(instructions: systemPrompt)
                return try await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            #endif
            throw AIError("Apple Intelligence isn't available on this Mac. Pick another provider in Settings › AI.")

        case .anthropic:
            let key = try apiKey(provider)
            var body: [String: Any] = [
                "model": settings.aiAnthropicModel,
                "max_tokens": 1024,
                "system": systemPrompt,
                "messages": [["role": "user", "content": prompt]],
                "output_config": ["effort": "low"],
            ]
            var headers = ["x-api-key": key, "anthropic-version": "2026-10-21"]
            // Haiku 5.5 has no server-side fallback; Sonnet 5.5 retries some refusals on another model.
            if settings.aiAnthropicModel == "claude-sonnet-5-5" {
                headers["anthropic-beta"] = "server-side-fallback-2026-07-01"
                body["fallbacks"] = "default"
            }
            let v = try await post("https://api.anthropic.com/v1/messages", body: body, headers: headers)
            if v["stop_reason"] as? String == "refusal" { throw AIError("The model declined to answer this one.") }
            let text = (v["content"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            return try nonEmpty(text)

        case .openai:
            let key = try apiKey(provider)
            let v = try await post(try base(settings.aiOpenaiURL) + "/chat/completions",
                                   body: ["model": settings.aiOpenaiModel, "messages": messages(prompt)],
                                   headers: ["Authorization": "Bearer \(key)"])
            let choice = (v["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
            return try nonEmpty(choice?["content"] as? String ?? "")

        case .ollama:
            let v = try await post(try base(settings.aiOllamaURL) + "/api/chat",
                                   body: ["model": settings.aiOllamaModel, "messages": messages(prompt), "stream": false], headers: [:])
            return try nonEmpty((v["message"] as? [String: Any])?["content"] as? String ?? "")
        }
    }

    private static func messages(_ prompt: String) -> [[String: String]] {
        [["role": "system", "content": systemPrompt], ["role": "user", "content": prompt]]
    }

    private static func apiKey(_ provider: AIProvider) throws -> String {
        guard let key = AIKeychain.get(provider), !key.isEmpty else { throw AIError("Add an API key in Settings › AI first.") }
        return key
    }

    private static func base(_ url: String) throws -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        guard s.hasPrefix("http://") || s.hasPrefix("https://") else { throw AIError("The base URL must start with http:// or https://") }
        return s
    }

    private static func nonEmpty(_ s: String) throws -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { throw AIError("Empty answer") }
        return t
    }

    private static func post(_ url: String, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        guard let u = URL(string: url) else { throw AIError("Invalid URL") }
        var req = URLRequest(url: u, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AIError("Couldn't reach the provider (\(error.localizedDescription))")
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard let v = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw AIError("The provider answered HTTP \(status)") }
        guard (200..<300).contains(status) else {
            let err = v["error"]
            throw AIError((err as? [String: Any])?["message"] as? String ?? err as? String ?? "The provider answered HTTP \(status)")
        }
        return v
    }
}
