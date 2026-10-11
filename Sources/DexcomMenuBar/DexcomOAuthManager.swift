import Foundation
import AuthenticationServices
import Network

/// Client responsible for Dexcom Developer API v3 OAuth2 Authorization & Event Sync
@MainActor
public final class DexcomOAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = DexcomOAuthManager()

    @Published public var isAuthorized: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authErrorMessage: String?
    @Published public var lastSyncTime: Date?

    private let tokenKey = "dexcom_v3_access_token"
    private let refreshKey = "dexcom_v3_refresh_token"
    private let tokenExpiryKey = "dexcom_v3_token_expiry"

    private var localListener: NWListener?
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        checkExistingAuth()
    }

    public func checkExistingAuth() {
        if let token = getAccessToken(), !token.isEmpty {
            self.isAuthorized = true
        } else {
            self.isAuthorized = false
        }
    }

    public func getAccessToken() -> String? {
        KeychainHelper.shared.read(key: tokenKey)
    }

    public func getRefreshToken() -> String? {
        KeychainHelper.shared.read(key: refreshKey)
    }

    private func saveTokens(accessToken: String, refreshToken: String?, expiresIn: Int) {
        _ = KeychainHelper.shared.save(key: tokenKey, value: accessToken)
        if let ref = refreshToken {
            _ = KeychainHelper.shared.save(key: refreshKey, value: ref)
        }
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: tokenExpiryKey)
        self.isAuthorized = true
        self.lastSyncTime = Date()
    }

    public func disconnect() {
        _ = KeychainHelper.shared.delete(key: tokenKey)
        _ = KeychainHelper.shared.delete(key: refreshKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        self.isAuthorized = false
        self.authErrorMessage = nil
    }

    /// 1-Click OAuth2 Browser Authorization Flow
    /// Launches ASWebAuthenticationSession pointing to Dexcom OAuth2 login portal
    public func start1ClickAuthorization(clientId: String, clientSecret: String, redirectURI: String = "http://localhost:8080/callback") {
        self.isAuthenticating = true
        self.authErrorMessage = nil

        // Standard Dexcom OAuth2 Authorize Endpoint
        // Production: https://api.dexcom.com/v2/oauth2/login
        guard var components = URLComponents(string: "https://api.dexcom.com/v2/oauth2/login") else {
            self.authErrorMessage = "Invalid Dexcom OAuth URL."
            self.isAuthenticating = false
            return
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "offline_access")
        ]

        guard let authURL = components.url else {
            self.authErrorMessage = "Failed to construct login URL."
            self.isAuthenticating = false
            return
        }

        // Start lightweight local HTTP callback server on port specified in redirectURI (default 8080)
        startLocalCallbackServer(clientId: clientId, clientSecret: clientSecret, redirectURI: redirectURI)

        // Callback scheme from redirectURI (e.g. http or custom)
        let scheme = URL(string: redirectURI)?.scheme ?? "http"

        // Launch system browser authentication session
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: scheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.isAuthenticating = false
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code != .canceledLogin {
                        self?.authErrorMessage = "Authentication error: \(error.localizedDescription)"
                    }
                    self?.stopLocalCallbackServer()
                    return
                }

                if let url = callbackURL, let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value {
                    await self?.exchangeCodeForTokens(code: code, clientId: clientId, clientSecret: clientSecret, redirectURI: redirectURI)
                }
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.authSession = session
        session.start()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first(where: { $0.isVisible }) ?? ASPresentationAnchor()
    }

    /// Exchange received Authorization Code for Dexcom Bearer Tokens
    private func exchangeCodeForTokens(code: String, clientId: String, clientSecret: String, redirectURI: String) async {
        guard let tokenURL = URL(string: "https://api.dexcom.com/v2/oauth2/token") else { return }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]

        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                self.authErrorMessage = "Invalid server response."
                return
            }

            if http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                let refreshToken = json["refresh_token"] as? String
                let expiresIn = json["expires_in"] as? Int ?? 7200
                saveTokens(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
                self.authErrorMessage = nil
            } else {
                if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDescription = errJson["error_description"] as? String ?? errJson["error"] as? String {
                    self.authErrorMessage = "Dexcom API rejected login: \(errorDescription)"
                } else {
                    self.authErrorMessage = "Dexcom OAuth token exchange returned HTTP \(http.statusCode)."
                }
            }
        } catch {
            self.authErrorMessage = "Failed to exchange auth token: \(error.localizedDescription)"
        }

        stopLocalCallbackServer()
    }

    /// Pushes an event (food, insulin, exercise, calibration) directly to Dexcom API v3 (`POST /v3/users/self/events`)
    public func postEventToDexcom(
        eventType: DexcomEventType,
        primaryValue: Double?,
        subtype: String?,
        date: Date,
        note: String?
    ) async -> Result<String, Error> {
        guard let token = getAccessToken(), !token.isEmpty else {
            return .failure(NSError(domain: "DexcomOAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No active OAuth2 connection. Connect with 1-click in Preferences."]))
        }

        guard let eventsURL = URL(string: "https://api.dexcom.com/v3/users/self/events") else {
            return .failure(NSError(domain: "DexcomOAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid events URL."]))
        }

        var request = URLRequest(url: eventsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let isoFormatter = ISO8601DateFormatter()
        let eventTimestamp = isoFormatter.string(from: date)

        var record: [String: Any] = [
            "systemTime": eventTimestamp,
            "displayTime": eventTimestamp
        ]

        switch eventType {
        case .food:
            record["eventType"] = "carbs"
            record["value"] = primaryValue ?? 0.0
            record["unit"] = "grams"
        case .insulin:
            record["eventType"] = "insulin"
            record["value"] = primaryValue ?? 0.0
            record["unit"] = "units"
            record["subType"] = (subtype == "Fast Acting") ? "fastActing" : "longActing"
        case .exercise:
            record["eventType"] = "exercise"
            record["value"] = primaryValue ?? 0.0
            record["unit"] = "minutes"
            record["subType"] = subtype ?? "medium"
        case .calibration:
            record["eventType"] = "bloodGlucose"
            record["value"] = primaryValue ?? 0.0
            record["unit"] = "mg/dL"
        case .sensor, .health:
            record["eventType"] = "note"
            record["value"] = note ?? ""
        }

        if let note = note, !note.isEmpty {
            record["note"] = note
        }

        let body: [String: Any] = ["records": [record]]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) {
                self.lastSyncTime = Date()
                return .success("Event successfully synced to Dexcom Clarity Cloud!")
            } else {
                let errString = String(data: data, encoding: .utf8) ?? "HTTP error"
                return .failure(NSError(domain: "DexcomOAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dexcom API rejected event: \(errString)"]))
            }
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Local Callback Listener (port dynamically parsed from redirectURI)
    private func startLocalCallbackServer(clientId: String, clientSecret: String, redirectURI: String) {
        stopLocalCallbackServer()
        let portInt = UInt16(URL(string: redirectURI)?.port ?? 8080)
        guard let port = NWEndpoint.Port(rawValue: portInt) else { return }
        do {
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data = data, let req = String(data: data, encoding: .utf8) else { return }

                    // Parse GET /callback?code=...
                    if let firstLine = req.components(separatedBy: "\r\n").first,
                       let queryPart = firstLine.components(separatedBy: " ").dropFirst().first,
                       let components = URLComponents(string: "http://localhost:\(portInt)" + queryPart),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {

                        // Send success HTML response back to browser
                        let html = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/html; charset=UTF-8\r
                        Connection: close\r
                        \r
                        <!DOCTYPE html>
                        <html>
                        <head><title>Dexcom Connected</title><style>body{font-family:-apple-system,sans-serif;background:#111;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}div{text-align:center;background:#222;padding:40px;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.5);}h1{color:#30d158;}</style></head>
                        <body><div><h1>✓ Dexcom Connected!</h1><p>Your Dexcom Developer Cloud authorization was successful.</p><p style="color:#888;">You can now close this tab and return to the menu bar app.</p></div></body>
                        </html>
                        """
                        connection.send(content: html.data(using: .utf8), completion: .contentProcessed({ _ in
                            connection.cancel()
                        }))

                        Task { @MainActor [weak self] in
                            await self?.exchangeCodeForTokens(code: code, clientId: clientId, clientSecret: clientSecret, redirectURI: redirectURI)
                        }
                    }
                }
            }
            listener.start(queue: .main)
            self.localListener = listener
        } catch {
            NSLog("[DexcomOAuth] Failed to start local callback listener: %@", error.localizedDescription)
        }
    }

    private func stopLocalCallbackServer() {
        localListener?.cancel()
        localListener = nil
    }
}
