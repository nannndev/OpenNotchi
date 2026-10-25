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
    case ninerouter, apple, ollama, anthropic, openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ninerouter: return "9router (your accounts)"
        case .apple: return "Apple Intelligence (on-device)"
        case .ollama: return "Ollama (local)"
        case .anthropic: return "Anthropic API"
        case .openai: return "OpenAI-compatible"
        }
    }

    var needsKey: Bool { self == .anthropic || self == .openai }

    /// Providers to offer: 9router only when installed, Apple Intelligence only when the on-device model is ready.
    static var available: [AIProvider] {
        allCases.filter {
            switch $0 {
            case .ninerouter: return NineRouterService.shared.isAvailable
            case .apple: return AIAssistant.appleAvailable
            default: return true
            }
        }
    }
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

    struct Message: Codable, Equatable {
        var role: String // "user" or "assistant"
        var content: String
        /// Attached clipboard / song / usage text: sent to the model before `content`, not shown in the bubble.
        var context: String? = nil
        /// Context labels shown as chips on the bubble.
        var attachments: [String]? = nil
        /// Base64 JPEGs sent with this message (vision models only).
        var images: [String]? = nil

        var full: String { (context.map { $0 + "\n\n" } ?? "") + content }

        /// OpenAI-style content: a string, or text + image parts.
        var openAIContent: Any {
            guard let images, !images.isEmpty else { return full }
            return [["type": "text", "text": full]] + images.map { ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\($0)"]] }
        }

        var anthropicContent: Any {
            guard let images, !images.isEmpty else { return full }
            return images.map { ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": $0]] } + [["type": "text", "text": full]]
        }
    }

    static func ask(_ prompt: String, settings: AppSettings = .shared) async throws -> String {
        try await chat([Message(role: "user", content: prompt)], settings: settings)
    }

    /// Sends a whole conversation. OpenAI-style providers (9router, OpenAI, Ollama) stream: `onDelta` gets
    /// each new chunk of text as it arrives. The others answer in one go and call `onDelta` once.
    @discardableResult
    static func chat(_ history: [Message], system: String = systemPrompt, settings: AppSettings = .shared,
                     onDelta: @escaping @MainActor (String) -> Void = { _ in }) async throws -> String {
        let provider = settings.aiProvider
        if provider == .apple, history.contains(where: { !($0.images ?? []).isEmpty }) {
            throw AIError("Apple Intelligence can't read images. Pick 9router or another provider for this chat.")
        }
        switch provider {
        case .ninerouter:
            guard let key = NineRouterService.shared.apiKey() else { throw AIError("No active API key in 9router. Create one in its dashboard › Endpoint & Key.") }
            let model = try await nineRouterModel(settings)
            return try await stream(NineRouterService.baseURL + "/chat/completions", model: model, history: history, system: system,
                                    headers: ["Authorization": "Bearer \(key)"], onDelta: onDelta)

        case .openai:
            let key = try apiKey(provider)
            return try await stream(try base(settings.aiOpenaiURL) + "/chat/completions", model: settings.aiOpenaiModel, history: history, system: system,
                                    headers: ["Authorization": "Bearer \(key)"], onDelta: onDelta)

        case .ollama:
            // Ollama serves the same OpenAI-compatible streaming API under /v1.
            return try await stream(try base(settings.aiOllamaURL) + "/v1/chat/completions", model: settings.aiOllamaModel, history: history, system: system,
                                    headers: [:], onDelta: onDelta)

        case .apple, .anthropic:
            let text = try await single(history, system: system, settings: settings)
            await onDelta(text)
            return text
        }
    }

    /// Providers without streaming here: Apple Intelligence (history flattened into one prompt) and Anthropic.
    private static func single(_ history: [Message], system: String, settings: AppSettings) async throws -> String {
        let provider = settings.aiProvider
        let prompt = history.last?.full ?? ""
        switch provider {
        case .ninerouter, .openai, .ollama:
            throw AIError("Unreachable")

        case .apple:
            #if canImport(FoundationModels)
            if #available(macOS 26, *), appleAvailable {
                let session = LanguageModelSession(instructions: system)
                let earlier = history.dropLast().map { "\($0.role == "user" ? "User" : "You"): \($0.full)" }.joined(separator: "\n\n")
                let full = earlier.isEmpty ? prompt : "Conversation so far:\n\(earlier)\n\nUser: \(prompt)"
                do {
                    return try await session.respond(to: full).content.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch let error as LanguageModelSession.GenerationError {
                    // Apple's on-device guardrails reject many harmless prompts; say so instead of "unsafe".
                    if case .guardrailViolation = error {
                        throw AIError("Apple Intelligence's safety filter blocked this prompt. Switch the model to 9router or another provider in Settings › AI.")
                    }
                    throw error
                }
            }
            #endif
            throw AIError("Apple Intelligence isn't available on this Mac. Pick another provider in Settings › AI.")

        case .anthropic:
            let key = try apiKey(provider)
            var body: [String: Any] = [
                "model": settings.aiAnthropicModel,
                "max_tokens": 2048,
                "system": system,
                "messages": history.map { ["role": $0.role, "content": $0.anthropicContent] },
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

        }
    }

    /// The text in one `data:` line of an OpenAI-style SSE stream; nil for keep-alives, role-only chunks and [DONE].
    static func sseDelta(_ line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]", let data = payload.data(using: .utf8),
              let v = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = (v["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String, !text.isEmpty else { return nil }
        return text
    }

    private static func stream(_ url: String, model: String, history: [Message], system: String, headers: [String: String],
                               onDelta: @escaping @MainActor (String) -> Void) async throws -> String {
        guard let u = URL(string: url) else { throw AIError("Invalid URL") }
        var req = URLRequest(url: u, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let msgs: [[String: Any]] = [["role": "system", "content": system]] + history.map { ["role": $0.role, "content": $0.openAIContent] }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "messages": msgs, "stream": true])

        let bytes: URLSession.AsyncBytes, resp: URLResponse
        do {
            (bytes, resp) = try await URLSession.shared.bytes(for: req)
        } catch {
            throw AIError("Couldn't reach the provider (\(error.localizedDescription))")
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var body = ""
            for try await line in bytes.lines { body += line }
            let v = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any]
            let err = v?["error"]
            throw AIError((err as? [String: Any])?["message"] as? String ?? err as? String ?? "The provider answered HTTP \(status)")
        }
        var text = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let delta = sseDelta(line) {
                text += delta
                await onDelta(delta)
            }
        }
        return try nonEmpty(text)
    }

    /// The chosen 9router model, or the first Haiku/Sonnet it offers so Ask works with no setup.
    private static func nineRouterModel(_ settings: AppSettings) async throws -> String {
        if !settings.aiNineRouterModel.isEmpty { return settings.aiNineRouterModel }
        let models = await NineRouterService.shared.models()
        guard let pick = models.first(where: { $0.contains("haiku") }) ?? models.first(where: { $0.contains("sonnet") }) ?? models.first else {
            throw AIError("9router isn't running. Start it, then try again.")
        }
        return pick
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
