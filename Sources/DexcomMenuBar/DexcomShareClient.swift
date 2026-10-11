import Foundation

public enum DexcomRegion: String, CaseIterable, Identifiable, Codable {
    case us = "US"
    case ous = "OUS (Outside US)"
    case jp = "Japan"

    public var id: String { rawValue }

    public var baseURL: URL {
        switch self {
        case .us:
            return URL(string: "https://share2.dexcom.com/ShareWebServices/Services")!
        case .ous:
            return URL(string: "https://shareous1.dexcom.com/ShareWebServices/Services")!
        case .jp:
            return URL(string: "https://share.dexcom.jp/ShareWebServices/Services")!
        }
    }

    public var applicationId: String {
        switch self {
        case .jp:
            return "d8665ade-9673-4e27-9ff6-92db4ce13d13"
        case .us, .ous:
            return "d89443d2-327c-4a6f-89e5-496bbb0317db"
        }
    }
}

public enum DexcomError: LocalizedError {
    case invalidCredentials
    case sessionExpired
    case networkError(Error)
    case serverError(Int)
    case decodingError(String)
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Dexcom username or password. (Server returned AccountPasswordInvalid)"
        case .sessionExpired:
            return "Dexcom Share session expired. Re-authenticating..."
        case .networkError(let err):
            return "Network connection issue: \(err.localizedDescription)"
        case .serverError(let code):
            if code == 500 {
                return "Dexcom HTTP 500: Server rejected the request. Please verify credentials and ensure Dexcom Share is enabled in the phone app."
            }
            return "Dexcom server responded with HTTP status code \(code)."
        case .decodingError(let msg):
            return "Failed to parse Dexcom response: \(msg)"
        case .noData:
            return "Connected to Dexcom Share, but 0 sensor readings were returned. If logged in with a Dexcom Follow account, note that Dexcom's Share endpoint only publishes readings when logged in with the CGM Wearer's primary account."
        }
    }
}

public actor DexcomShareClient {
    private var sessionId: String?
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Authenticate with Dexcom Share API and retrieve an active Session ID
    public func login(username: String, password: String, region: DexcomRegion, accountType: DexcomAccountType = .sharer) async throws -> String {
        // Try Method 1: LoginPublisherAccountByName (single step, supported across versions)
        do {
            let directURL = region.baseURL.appendingPathComponent("General/LoginPublisherAccountByName")
            var directRequest = URLRequest(url: directURL)
            directRequest.httpMethod = "POST"
            directRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            directRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            directRequest.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

            let body: [String: Any] = [
                "accountName": username,
                "password": password,
                "applicationId": region.applicationId
            ]
            directRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await urlSession.data(for: directRequest)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let sid = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n")),
               !sid.isEmpty, sid != "00000000-0000-0000-0000-000000000000" {
                self.sessionId = sid
                return sid
            }
        } catch {
            // Fall through to 2-step authentication
        }

        // Method 2: 2-step AuthenticatePublisherAccount -> LoginPublisherAccountById
        let authURL = region.baseURL.appendingPathComponent("General/AuthenticatePublisherAccount")
        var authRequest = URLRequest(url: authURL)
        authRequest.httpMethod = "POST"
        authRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        authRequest.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

        let authBody: [String: Any] = [
            "accountName": username,
            "password": password,
            "applicationId": region.applicationId
        ]
        authRequest.httpBody = try JSONSerialization.data(withJSONObject: authBody)

        let (authData, authResponse) = try await urlSession.data(for: authRequest)
        guard let httpAuthResponse = authResponse as? HTTPURLResponse else {
            throw DexcomError.serverError(-1)
        }

        if httpAuthResponse.statusCode != 200 {
            if let faultJson = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
               let code = faultJson["Code"] as? String {
                if code == "AccountPasswordInvalid" {
                    throw DexcomError.invalidCredentials
                } else if code == "AccountNotFound" {
                    throw DexcomError.decodingError("Account not found. Please verify your username / phone number or region.")
                } else if let message = faultJson["Message"] as? String {
                    throw DexcomError.decodingError("Dexcom error: \(message) (\(code))")
                }
            }
            if httpAuthResponse.statusCode == 500 {
                throw DexcomError.decodingError("Dexcom Share API rejected login with 500. Dexcom strictly requires the CGM wearer's primary login. Follower accounts cannot be used.")
            }
            throw DexcomError.serverError(httpAuthResponse.statusCode)
        }

        guard let accountIdRaw = String(data: authData, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n")),
              !accountIdRaw.isEmpty,
              accountIdRaw != "00000000-0000-0000-0000-000000000000" else {
            throw DexcomError.invalidCredentials
        }

        // Step 2: LoginPublisherAccountById to obtain Session ID
        let loginURL = region.baseURL.appendingPathComponent("General/LoginPublisherAccountById")
        var loginRequest = URLRequest(url: loginURL)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        loginRequest.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")

        let loginBody: [String: Any] = [
            "accountId": accountIdRaw,
            "password": password,
            "applicationId": region.applicationId
        ]
        loginRequest.httpBody = try JSONSerialization.data(withJSONObject: loginBody)

        let (loginData, loginResp) = try await urlSession.data(for: loginRequest)
        guard let httpLoginResp = loginResp as? HTTPURLResponse else {
            throw DexcomError.serverError(-1)
        }

        if httpLoginResp.statusCode != 200 {
            if let faultJson = try? JSONSerialization.jsonObject(with: loginData) as? [String: Any],
               let code = faultJson["Code"] as? String {
                if code == "AccountPasswordInvalid" {
                    throw DexcomError.invalidCredentials
                } else if let message = faultJson["Message"] as? String {
                    throw DexcomError.decodingError("Dexcom error: \(message) (\(code))")
                }
            }
            throw DexcomError.serverError(httpLoginResp.statusCode)
        }

        guard let newSessionId = String(data: loginData, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n")),
              !newSessionId.isEmpty,
              newSessionId != "00000000-0000-0000-0000-000000000000" else {
            throw DexcomError.invalidCredentials
        }

        self.sessionId = newSessionId
        return newSessionId
    }

    /// Fetch latest readings (defaults to 1440 minutes / 24 hours, maxCount = 24)
    public func fetchLatestReadings(
        username: String,
        password: String,
        region: DexcomRegion,
        accountType: DexcomAccountType = .sharer,
        minutes: Int = 1440,
        maxCount: Int = 24
    ) async throws -> [GlucoseReading] {
        if sessionId == nil {
            _ = try await login(username: username, password: password, region: region, accountType: accountType)
        }

        do {
            return try await executeFetch(region: region, minutes: minutes, maxCount: maxCount)
        } catch DexcomError.sessionExpired {
            // Re-authenticate once and retry
            _ = try await login(username: username, password: password, region: region, accountType: accountType)
            return try await executeFetch(region: region, minutes: minutes, maxCount: maxCount)
        }
    }

    private func executeFetch(region: DexcomRegion, minutes: Int, maxCount: Int) async throws -> [GlucoseReading] {
        guard let sid = sessionId else {
            throw DexcomError.sessionExpired
        }

        // Dexcom's WCF IIS endpoint ReadPublisherLatestGlucoseValues is strictly designed for query parameters
        // with an empty body (Content-Length: 0). Passing a JSON body can confuse the WCF dispatcher into ignoring
        // or failing the query string.
        var components = URLComponents(url: region.baseURL.appendingPathComponent("Publisher/ReadPublisherLatestGlucoseValues"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "sessionId", value: sid),
            URLQueryItem(name: "minutes", value: "\(minutes)"),
            URLQueryItem(name: "maxCount", value: "\(maxCount)")
        ]

        guard let requestURL = components?.url else {
            throw DexcomError.decodingError("Invalid URL query composition")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.httpBody = nil

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DexcomError.serverError(-1)
        }

        if httpResponse.statusCode == 500 {
            self.sessionId = nil
            throw DexcomError.sessionExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw DexcomError.serverError(httpResponse.statusCode)
        }

        var readings = try parseReadings(from: data)
        
        // If empty, also attempt with request body in case this region server expects payload
        if readings.isEmpty {
            var bodyRequest = URLRequest(url: requestURL)
            bodyRequest.httpMethod = "POST"
            bodyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            bodyRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            bodyRequest.setValue("Dexcom Share/3.0.2.11 CFNetwork/672.0.2 Darwin/14.0.0", forHTTPHeaderField: "User-Agent")
            let payload: [String: Any] = [
                "sessionId": sid,
                "sessionID": sid,
                "minutes": minutes,
                "maxCount": maxCount
            ]
            bodyRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            if let (bodyData, bodyResp) = try? await urlSession.data(for: bodyRequest),
               let httpBodyResp = bodyResp as? HTTPURLResponse, httpBodyResp.statusCode == 200,
               let bodyReadings = try? parseReadings(from: bodyData), !bodyReadings.isEmpty {
                readings = bodyReadings
            }
        }

        if readings.isEmpty {
            throw DexcomError.noData
        }
        return readings
    }

    private func parseReadings(from data: Data) throws -> [GlucoseReading] {
        guard let rawArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw DexcomError.decodingError("Response was not a JSON array")
        }

        var results: [GlucoseReading] = []

        for item in rawArray {
            guard let val = item["Value"] as? Double ?? (item["Value"] as? Int).map(Double.init),
                  let trendStr = item["Trend"] as? String else {
                continue
            }

            // Dexcom timestamp format: "/Date(1620000000000)/" or Date string
            var timestamp = Date()
            if let dateString = item["WT"] as? String ?? item["DT"] as? String ?? item["ST"] as? String {
                if let match = dateString.range(of: "\\d+", options: .regularExpression),
                   let epochMs = Double(dateString[match]) {
                    timestamp = Date(timeIntervalSince1970: epochMs / 1000.0)
                }
            }

            let trend = parseTrend(from: trendStr)
            results.append(GlucoseReading(value: val, trend: trend, timestamp: timestamp))
        }

        // Sort descending by timestamp (newest first)
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseTrend(from string: String) -> GlucoseTrend {
        if let trend = GlucoseTrend(rawValue: string) {
            return trend
        }
        // Also support numeric string fallback if received
        switch string {
        case "1": return .doubleUp
        case "2": return .singleUp
        case "3": return .fortyFiveUp
        case "4": return .flat
        case "5": return .fortyFiveDown
        case "6": return .singleDown
        case "7": return .doubleDown
        default: return .none
        }
    }
}
