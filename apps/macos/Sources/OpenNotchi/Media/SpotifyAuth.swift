import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Spotify account login (Authorization Code with PKCE, no client secret).
/// Tokens live in the Keychain.
final class SpotifyAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SpotifyAuth()

    /// The project's Spotify app. Spotify limits apps in development mode to 25
    /// allow-listed users, so others can paste their own Client ID in Settings.
    static let defaultClientID = "9e2d96c8642b4f4fa2274d95cc5ef0da"
    static let redirectURI = "opennotchi://spotify-callback"
    private static let scopes = "user-read-playback-state user-read-currently-playing user-modify-playback-state"

    @Published private(set) var isLoggedIn = false
    @Published private(set) var accountName: String?
    @Published private(set) var isAuthorizing = false
    @Published private(set) var lastError: String?

    private struct Tokens: Codable {
        var access: String
        var refresh: String
        var expires: Date
    }

    private let lock = NSLock()
    private var tokens: Tokens?
    private var session: ASWebAuthenticationSession?
    private var pendingRefresh: [(String?) -> Void] = []

    var clientID: String {
        let custom = AppSettings.shared.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? Self.defaultClientID : custom
    }

    private override init() {
        super.init()
        tokens = Keychain.load()
        isLoggedIn = tokens != nil
        accountName = UserDefaults.standard.string(forKey: "spotifyAccountName")
    }

    // MARK: - Login

    func connect() {
        guard !clientID.isEmpty else {
            lastError = "Add your Spotify Client ID first."
            return
        }
        lastError = nil
        let verifier = Self.randomString(length: 64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "state", value: state),
        ]

        let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "opennotchi") { [weak self] url, error in
            DispatchQueue.main.async {
                self?.isAuthorizing = false
                guard let self else { return }
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin { return }
                let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
                let value = { (name: String) in items.first { $0.name == name }?.value }
                guard value("state") == state, let code = value("code") else {
                    self.lastError = value("error").map { "Spotify said: \($0)" } ?? "Login didn't finish."
                    return
                }
                self.exchange(code: code, verifier: verifier)
            }
        }
        session.presentationContextProvider = self
        self.session = session
        isAuthorizing = true
        session.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.canBecomeKey } ?? NSWindow()
    }

    func disconnect() {
        lock.withLock { tokens = nil }
        Keychain.delete()
        UserDefaults.standard.removeObject(forKey: "spotifyAccountName")
        isLoggedIn = false
        accountName = nil
    }

    private func exchange(code: String, verifier: String) {
        postToken([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ]) { [weak self] tokens in
            guard let self else { return }
            guard let tokens else {
                self.lastError = "Couldn't finish signing in. Check the Client ID and the redirect URI."
                return
            }
            self.store(tokens)
            self.loadProfile()
        }
    }

    private func loadProfile() {
        withAccessToken { token in
            guard let token else { return }
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // SpotifyAuth is a singleton, so capturing self strongly is fine.
            URLSession.shared.dataTask(with: request) { data, _, _ in
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let name = json?["display_name"] as? String ?? json?["id"] as? String
                DispatchQueue.main.async {
                    self.accountName = name
                    UserDefaults.standard.set(name, forKey: "spotifyAccountName")
                }
            }.resume()
        }
    }

    // MARK: - Tokens

    /// Calls back with a valid access token (refreshing it when needed), or nil when logged out.
    func withAccessToken(_ completion: @escaping (String?) -> Void) {
        lock.lock()
        guard let current = tokens else {
            lock.unlock()
            return completion(nil)
        }
        if current.expires.timeIntervalSinceNow > 60 {
            lock.unlock()
            return completion(current.access)
        }
        pendingRefresh.append(completion)
        let alreadyRefreshing = pendingRefresh.count > 1
        lock.unlock()
        guard !alreadyRefreshing else { return }

        postToken(["grant_type": "refresh_token", "refresh_token": current.refresh, "client_id": clientID]) { [weak self] refreshed in
            guard let self else { return }
            if let refreshed {
                self.store(refreshed)
            } else {
                // Revoked or expired for good: sign out so Settings shows Connect again.
                self.disconnect()
            }
            self.lock.lock()
            let waiting = self.pendingRefresh
            self.pendingRefresh = []
            self.lock.unlock()
            waiting.forEach { $0(refreshed?.access) }
        }
    }

    private func store(_ new: Tokens) {
        lock.withLock { tokens = new }
        Keychain.save(new)
        DispatchQueue.main.async { self.isLoggedIn = true }
    }

    /// Posts to the token endpoint; calls back on the main thread.
    private func postToken(_ form: [String: String], completion: @escaping (Tokens?) -> Void) {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let previousRefresh = lock.withLock { tokens?.refresh }
        URLSession.shared.dataTask(with: request) { data, response, _ in
            var result: Tokens?
            if (response as? HTTPURLResponse)?.statusCode == 200,
               let json = data.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
               let access = json["access_token"] as? String {
                let refresh = json["refresh_token"] as? String ?? previousRefresh ?? ""
                let expiresIn = json["expires_in"] as? Double ?? 3600
                result = Tokens(access: access, refresh: refresh, expires: Date().addingTimeInterval(expiresIn))
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func randomString(length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    // MARK: - Keychain

    private enum Keychain {
        private static let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.github.opennotchi.spotify",
            kSecAttrAccount as String: "tokens",
        ]

        static func load() -> Tokens? {
            var q = query
            q[kSecReturnData as String] = true
            var item: CFTypeRef?
            guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
            return try? JSONDecoder().decode(Tokens.self, from: data)
        }

        static func save(_ tokens: Tokens) {
            guard let data = try? JSONEncoder().encode(tokens) else { return }
            let attributes = [kSecValueData as String: data]
            if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
                var q = query
                q[kSecValueData as String] = data
                SecItemAdd(q as CFDictionary, nil)
            }
        }

        static func delete() {
            SecItemDelete(query as CFDictionary)
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
