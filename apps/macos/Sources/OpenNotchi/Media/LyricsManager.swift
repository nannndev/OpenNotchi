import Combine
import Foundation
import NaturalLanguage
import Translation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

/// Fetches lyrics for the current track from LRCLIB (https://lrclib.net),
/// a free, open lyrics database that needs no API key.
final class LyricsManager: ObservableObject {
    enum State: Equatable {
        case idle, loading, synced, plain, instrumental, notFound
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lines: [LyricLine] = []
    @Published private(set) var plainText: String?
    /// Translated lyrics keyed by the original line text.
    @Published private(set) var translations: [String: String] = [:]
    /// Why lyrics aren't translated (missing language pack, old macOS), shown in Settings.
    @Published private(set) var translationIssue: String?
    private var translateTask: Task<Void, Never>?

    private let settings: AppSettings
    private var trackKey: String?
    private var task: URLSessionDataTask?
    private var cancellables: Set<AnyCancellable> = []
    private var cache: [String: (State, [LyricLine], String?)] = [:]
    private var lastRequestFailed = false
    private var lastInfo: NowPlayingInfo?

    init(media: MediaManager, settings: AppSettings) {
        self.settings = settings
        media.$info
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in self?.trackChanged(info) }
            .store(in: &cancellables)
    }

    /// Index of the line being sung at `position` seconds.
    func currentIndex(at position: Double) -> Int? {
        guard state == .synced else { return nil }
        return lines.lastIndex { $0.time <= position + 0.25 }
    }

    func currentLine(at position: Double) -> String? {
        guard let index = currentIndex(at: position) else { return nil }
        let text = lines[index].text
        return text.isEmpty ? nil : text
    }

    private func trackChanged(_ info: NowPlayingInfo?) {
        if info?.sourceID == "demo" {
            let text = ["Headlights painting the empty road", "Radio humming a song we know", "Every stop light turning green",
                        "Midnight drive, just you and me", "City sleeping, we're wide awake", "Turn it up for the long way home"]
            trackKey = info?.trackKey
            apply(.synced, text.enumerated().map { LyricLine(id: $0.offset, time: Double(60 + $0.offset * 5), text: $0.element) }, nil, key: nil)
            return
        }
        guard settings.lyricsEnabled, let info else {
            if info == nil { apply(.idle, [], nil, key: nil) }
            return
        }
        guard info.trackKey != trackKey else { return }
        trackKey = info.trackKey
        task?.cancel()

        // YouTube videos (not YouTube Music songs) almost never have lyrics; don't look them up.
        if info.videoID != nil {
            apply(.notFound, [], nil, key: nil)
            return
        }

        if let cached = cache[info.trackKey] {
            apply(cached.0, cached.1, cached.2, key: info.trackKey)
            return
        }
        load(info)
    }

    private func load(_ info: NowPlayingInfo) {
        lastInfo = info
        lastRequestFailed = false
        apply(.loading, [], nil, key: info.trackKey)
        fetchExact(info)
    }

    /// Retries a lookup that failed because of the network (not a real "no lyrics").
    func retryIfNeeded() {
        retryTranslationIfNeeded()
        guard state == .notFound, cache[trackKey ?? ""] == nil, let lastInfo, lastInfo.trackKey == trackKey else { return }
        load(lastInfo)
    }

    /// Tries again after a failed translation, e.g. once the user has downloaded the language pack.
    func retryTranslationIfNeeded() {
        if translationIssue != nil { translateIfNeeded() }
    }

    private func apply(_ state: State, _ lines: [LyricLine], _ plain: String?, key: String?) {
        self.state = state
        self.lines = lines
        self.plainText = plain
        let transientFailure = state == .notFound && lastRequestFailed
        if let key, state != .loading, !transientFailure { cache[key] = (state, lines, plain) }
        translateIfNeeded()
    }

    // MARK: - Translation

    /// Translates the current lyrics on-device into the language chosen in Settings.
    func translateIfNeeded() {
        translateTask?.cancel()
        translations = [:]
        translationIssue = nil
        guard settings.lyricsTranslate else { return }

        let source = state == .synced ? lines.map(\.text) : (plainText ?? "").components(separatedBy: .newlines)
        let texts = Array(Set(source.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }))
        guard !texts.isEmpty else { return }
        guard #available(macOS 26, *) else {
            translationIssue = "Translating lyrics needs macOS 26 or later."
            return
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(texts.joined(separator: "\n"))
        guard let detected = recognizer.dominantLanguage else { return }
        let from = Locale.Language(identifier: detected.rawValue)
        let to = Locale.Language(identifier: settings.lyricsTranslateTarget)
        guard from.languageCode != to.languageCode else {
            let name = Locale.current.localizedString(forLanguageCode: detected.rawValue) ?? detected.rawValue
            translationIssue = "This song is already in \(name). Pick another language to translate into."
            return
        }

        let key = trackKey
        translateTask = Task { @MainActor [weak self] in
            // Language packs can finish downloading while a song plays: keep checking until they're ready.
            defer {
                if !Task.isCancelled, self?.translationIssue != nil, self?.trackKey == key {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                        if self?.trackKey == key { self?.retryTranslationIfNeeded() }
                    }
                }
            }
            do {
                let result = try await Self.translate(texts, from: from, to: to)
                guard !Task.isCancelled, self?.trackKey == key else { return }
                self?.translations = result
            } catch let issue as TranslationIssue {
                self?.translationIssue = issue.message
            } catch {
                if !Task.isCancelled { self?.translationIssue = "Couldn't translate these lyrics." }
            }
        }
    }

    private struct TranslationIssue: Error { let message: String }

    @available(macOS 26, *)
    private static func translate(_ texts: [String], from: Locale.Language, to: Locale.Language) async throws -> [String: String] {
        // Translate first; the availability status can lag behind packs that are already usable.
        do {
            let session = TranslationSession(installedSource: from, target: to)
            // Responses can come back reordered and with normalized text, so match them by index.
            let requests = texts.enumerated().map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
            let responses = try await session.translations(from: requests)
            return Dictionary(responses.compactMap { response in
                response.clientIdentifier.flatMap(Int.init).map { (texts[$0], response.targetText) }
            }, uniquingKeysWith: { first, _ in first })
        } catch {
            NSLog("OpenNotchi lyrics translation %@ → %@ failed: %@", from.maximalIdentifier, to.maximalIdentifier, String(describing: error))
            let name = Locale.current.localizedString(forLanguageCode: from.languageCode?.identifier ?? "") ?? "this language"
            switch await LanguageAvailability().status(from: from, to: to) {
            case .supported:
                throw TranslationIssue(message: "Download \(name) in System Settings › General › Language & Region › Translation Languages.")
            case .unsupported:
                throw TranslationIssue(message: "Translating from \(name) isn't supported.")
            default:
                throw error
            }
        }
    }

    // MARK: - Networking

    private struct Record: Decodable {
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private func fetchExact(_ info: NowPlayingInfo) {
        var items = [
            URLQueryItem(name: "track_name", value: info.title),
            URLQueryItem(name: "artist_name", value: info.artist),
            URLQueryItem(name: "album_name", value: info.album),
        ]
        if info.duration > 0 { items.append(URLQueryItem(name: "duration", value: String(Int(info.duration.rounded())))) }

        request(path: "/api/get", items: items) { [weak self] (record: Record?) in
            if let record, record.syncedLyrics != nil || record.plainLyrics != nil || record.instrumental == true {
                self?.finish(record, key: info.trackKey)
            } else {
                self?.fetchSearch(info)
            }
        }
    }

    /// Looser fallback: strips suffixes like "- Remastered 2009" and searches.
    private func fetchSearch(_ info: NowPlayingInfo) {
        let items = [
            URLQueryItem(name: "track_name", value: Self.cleanTitle(info.title)),
            URLQueryItem(name: "artist_name", value: info.artist),
        ]
        request(path: "/api/search", items: items) { [weak self] (records: [Record]?) in
            let best = records?.first { $0.syncedLyrics != nil } ?? records?.first
            if let best {
                self?.finish(best, key: info.trackKey)
            } else {
                self?.finishNotFound(key: info.trackKey)
            }
        }
    }

    private func request<T: Decodable>(path: String, items: [URLQueryItem], completion: @escaping (T?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net")!
        components.path = path
        components.queryItems = items
        guard let url = components.url else { return completion(nil) }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("OpenNotchi (https://github.com/opennotchi/opennotchi)", forHTTPHeaderField: "User-Agent")

        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            let ok = status == 200
            // Anything other than a clean 200/404 is a network problem worth retrying later.
            if (error as? URLError)?.code != .cancelled, !ok, status != 404 {
                DispatchQueue.main.async { self?.lastRequestFailed = true }
            }
            let value = ok ? data.flatMap { try? JSONDecoder().decode(T.self, from: $0) } : nil
            DispatchQueue.main.async { completion(value) }
        }
        task?.resume()
    }

    private func finish(_ record: Record, key: String) {
        guard key == trackKey else { return }
        if let synced = record.syncedLyrics, case let lines = Self.parseLRC(synced), !lines.isEmpty {
            apply(.synced, lines, record.plainLyrics, key: key)
        } else if let plain = record.plainLyrics, !plain.isEmpty {
            apply(.plain, [], plain, key: key)
        } else if record.instrumental == true {
            apply(.instrumental, [], nil, key: key)
        } else {
            finishNotFound(key: key)
        }
    }

    private func finishNotFound(key: String) {
        guard key == trackKey else { return }
        apply(.notFound, [], nil, key: key)
    }

    // MARK: - Parsing

    static func parseLRC(_ text: String) -> [LyricLine] {
        let pattern = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var result: [(Double, String)] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let ns = rawLine as NSString
            let matches = pattern.matches(in: rawLine, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let lyric = ns.substring(from: last.range.location + last.range.length)
                .trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
                result.append((minutes * 60 + seconds, lyric))
            }
        }

        return result
            .sorted { $0.0 < $1.0 }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    static func cleanTitle(_ title: String) -> String {
        var cleaned = title
        if let range = cleaned.range(of: " - ", options: .backwards) {
            let suffix = cleaned[range.upperBound...].lowercased()
            let markers = ["remaster", "live", "version", "mono", "stereo", "edit", "mix", "deluxe"]
            if markers.contains(where: suffix.contains) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        if let paren = cleaned.range(of: #"\s*[\(\[](feat|ft|with)\.?[^\)\]]*[\)\]]"#, options: [.regularExpression, .caseInsensitive]) {
            cleaned.removeSubrange(paren)
        }
        return cleaned
    }
}
