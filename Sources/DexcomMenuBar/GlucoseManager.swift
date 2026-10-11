import Foundation
import Combine
import SwiftUI
import UserNotifications

public extension Notification.Name {
    static let glucoseDataUpdated = Notification.Name("glucoseDataUpdated")
}

/// Identifiers for multiple user profiles
public enum UserProfileID: String, CaseIterable, Identifiable, Codable {
    case user1 = "user1"
    case user2 = "user2"

    public var id: String { rawValue }

    public var defaultName: String {
        switch self {
        case .user1: return "User 1"
        case .user2: return "User 2"
        }
    }
}

@MainActor
public final class GlucoseManager: ObservableObject {
    // Current active profile selected in the popped-out menu bar card
    @Published public var activeProfileId: UserProfileID = .user1

    // Global / shared settings
    @AppStorage("glucose_unit") public var unitRaw: String = GlucoseUnit.mgdL.rawValue
    @AppStorage("demo_mode") public var demoMode: Bool = false
    @AppStorage("sync_targets_with_dexcom") public var syncTargetsWithDexcom: Bool = true
    @AppStorage("visible_log_categories") public var visibleLogCategoriesRaw: String = "Food,Insulin,Exercise,BGM Cal,Sensor,Health / Note"

    // Multi-User Configuration
    @AppStorage("user2_enabled") public var user2Enabled: Bool = false
    @AppStorage("profile_order") public var profileOrderRaw: String = "user1,user2" // comma-separated profile IDs

    // Profile 1 Settings
    @AppStorage("p1_name") public var p1Name: String = "User 1"
    @AppStorage("p1_username") public var p1Username: String = ""
    @AppStorage("p1_region") public var p1RegionRaw: String = DexcomRegion.us.rawValue
    @AppStorage("p1_color_icon_enabled") public var p1ColorIconEnabled: Bool = true
    @AppStorage("p1_low_icon_color") public var p1LowIconColorRaw: String = AppColorOption.red.rawValue
    @AppStorage("p1_normal_icon_color") public var p1NormalIconColorRaw: String = NormalColorOption.green.rawValue
    @AppStorage("p1_high_icon_color") public var p1HighIconColorRaw: String = AppColorOption.orange.rawValue
    @AppStorage("p1_show_menubar_chart") public var p1ShowMenuBarTrendChart: Bool = false
    @AppStorage("p1_show_delta_change") public var p1ShowDeltaChange: Bool = false
    @AppStorage("p1_show_log_button") public var p1ShowLogButton: Bool = true
    @AppStorage("p1_low_threshold") public var p1LowThreshold: Double = 70.0
    @AppStorage("p1_high_threshold") public var p1HighThreshold: Double = 180.0
    @AppStorage("p1_urgent_low_threshold") public var p1UrgentLowThreshold: Double = 55.0
    @AppStorage("p1_urgent_high_threshold") public var p1UrgentHighThreshold: Double = 250.0
    @AppStorage("p1_urgent_low_sound") public var p1UrgentLowSoundRaw: String = AlertSoundOption.sosumi.rawValue
    @AppStorage("p1_urgent_high_sound") public var p1UrgentHighSoundRaw: String = AlertSoundOption.hero.rawValue
    @AppStorage("p1_notifications_enabled") public var p1NotificationsEnabled: Bool = true
    @AppStorage("p1_sensor_tracking_enabled") public var p1SensorTrackingEnabled: Bool = false
    @AppStorage("p1_sensor_model") public var p1SensorModelRaw: String = DexcomSensorModel.g7.rawValue
    @AppStorage("p1_sensor_start_timestamp") public var p1SensorStartTimestamp: Double = 0.0

    // Profile 2 Settings
    @AppStorage("p2_name") public var p2Name: String = "User 2"
    @AppStorage("p2_username") public var p2Username: String = ""
    @AppStorage("p2_region") public var p2RegionRaw: String = DexcomRegion.us.rawValue
    @AppStorage("p2_color_icon_enabled") public var p2ColorIconEnabled: Bool = true
    @AppStorage("p2_low_icon_color") public var p2LowIconColorRaw: String = AppColorOption.blue.rawValue
    @AppStorage("p2_normal_icon_color") public var p2NormalIconColorRaw: String = NormalColorOption.green.rawValue
    @AppStorage("p2_high_icon_color") public var p2HighIconColorRaw: String = AppColorOption.purple.rawValue
    @AppStorage("p2_show_menubar_chart") public var p2ShowMenuBarTrendChart: Bool = true
    @AppStorage("p2_show_delta_change") public var p2ShowDeltaChange: Bool = true
    @AppStorage("p2_show_log_button") public var p2ShowLogButton: Bool = true
    @AppStorage("p2_low_threshold") public var p2LowThreshold: Double = 70.0
    @AppStorage("p2_high_threshold") public var p2HighThreshold: Double = 180.0
    @AppStorage("p2_urgent_low_threshold") public var p2UrgentLowThreshold: Double = 55.0
    @AppStorage("p2_urgent_high_threshold") public var p2UrgentHighThreshold: Double = 250.0
    @AppStorage("p2_urgent_low_sound") public var p2UrgentLowSoundRaw: String = AlertSoundOption.glass.rawValue
    @AppStorage("p2_urgent_high_sound") public var p2UrgentHighSoundRaw: String = AlertSoundOption.ping.rawValue
    @AppStorage("p2_notifications_enabled") public var p2NotificationsEnabled: Bool = true
    @AppStorage("p2_sensor_tracking_enabled") public var p2SensorTrackingEnabled: Bool = false
    @AppStorage("p2_sensor_model") public var p2SensorModelRaw: String = DexcomSensorModel.g7.rawValue
    @AppStorage("p2_sensor_start_timestamp") public var p2SensorStartTimestamp: Double = 0.0

    // Runtime state per profile
    @Published public var p1CurrentReading: GlucoseReading?
    @Published public var p1RecentReadings: [GlucoseReading] = []
    @Published public var p1IsLoading: Bool = false
    @Published public var p1ErrorMessage: String?
    @Published public var p1LastSuccessfulFetch: Date?

    @Published public var p2CurrentReading: GlucoseReading?
    @Published public var p2RecentReadings: [GlucoseReading] = []
    @Published public var p2IsLoading: Bool = false
    @Published public var p2ErrorMessage: String?
    @Published public var p2LastSuccessfulFetch: Date?

    private var pollTimer: Timer?
    private var p1RetryCount: Int = 0
    private var p2RetryCount: Int = 0
    private let maxBackoffSeconds: TimeInterval = 300
    private let p1Client = DexcomShareClient()
    private let p2Client = DexcomShareClient()

    private var p1LastAlertedReadingId: UUID?
    private var p1LastAlertTime: Date?
    private var p2LastAlertedReadingId: UUID?
    private var p2LastAlertTime: Date?

    public init() {
        migrateLegacyKeysIfNeeded()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Migrate single-user legacy keys so existing users don't lose their logins or settings
    private func migrateLegacyKeysIfNeeded() {
        let legacyUsername = UserDefaults.standard.string(forKey: "dexcom_username") ?? ""
        if !legacyUsername.isEmpty && p1Username.isEmpty {
            p1Username = legacyUsername
        }
        if let legacyRegion = UserDefaults.standard.string(forKey: "dexcom_region"), !legacyRegion.isEmpty {
            if UserDefaults.standard.string(forKey: "p1_region") == nil || p1RegionRaw == DexcomRegion.us.rawValue {
                p1RegionRaw = legacyRegion
            }
        }
        if let legacyPass = KeychainHelper.shared.read(key: "dexcom_password"), !legacyPass.isEmpty {
            if getPassword(for: .user1).isEmpty {
                setPassword(legacyPass, for: .user1)
            }
        }
        if UserDefaults.standard.object(forKey: "low_threshold") != nil {
            p1LowThreshold = UserDefaults.standard.double(forKey: "low_threshold")
        }
        if UserDefaults.standard.object(forKey: "high_threshold") != nil {
            p1HighThreshold = UserDefaults.standard.double(forKey: "high_threshold")
        }
        if UserDefaults.standard.object(forKey: "urgent_low_threshold") != nil {
            p1UrgentLowThreshold = UserDefaults.standard.double(forKey: "urgent_low_threshold")
        }
        if UserDefaults.standard.object(forKey: "urgent_high_threshold") != nil {
            p1UrgentHighThreshold = UserDefaults.standard.double(forKey: "urgent_high_threshold")
        }
        if let s = UserDefaults.standard.string(forKey: "color_icon_enabled") {
            p1ColorIconEnabled = (s == "true" || UserDefaults.standard.bool(forKey: "color_icon_enabled"))
        }
        if let s = UserDefaults.standard.string(forKey: "low_icon_color") {
            p1LowIconColorRaw = s
        }
        if let s = UserDefaults.standard.string(forKey: "high_icon_color") {
            p1HighIconColorRaw = s
        }
        if let s = UserDefaults.standard.string(forKey: "normal_icon_color") {
            p1NormalIconColorRaw = s
        }
        if let s = UserDefaults.standard.string(forKey: "urgent_low_sound") {
            p1UrgentLowSoundRaw = s
        }
        if let s = UserDefaults.standard.string(forKey: "urgent_high_sound") {
            p1UrgentHighSoundRaw = s
        }
        if UserDefaults.standard.object(forKey: "show_menubar_chart") != nil {
            p1ShowMenuBarTrendChart = UserDefaults.standard.bool(forKey: "show_menubar_chart")
        }
        if UserDefaults.standard.object(forKey: "show_delta_change") != nil {
            p1ShowDeltaChange = UserDefaults.standard.bool(forKey: "show_delta_change")
        }
        if UserDefaults.standard.object(forKey: "sensor_tracking_enabled") != nil {
            p1SensorTrackingEnabled = UserDefaults.standard.bool(forKey: "sensor_tracking_enabled")
        }
        if let s = UserDefaults.standard.string(forKey: "sensor_model") {
            p1SensorModelRaw = s
        }
        if UserDefaults.standard.object(forKey: "sensor_start_timestamp") != nil {
            p1SensorStartTimestamp = UserDefaults.standard.double(forKey: "sensor_start_timestamp")
        }
    }

    // MARK: - Profiles Order & Resolution
    public var configuredProfileOrder: [UserProfileID] {
        get {
            let parts = profileOrderRaw.split(separator: ",").map { String($0) }
            var list = parts.compactMap { UserProfileID(rawValue: $0) }
            if list.isEmpty {
                list = [.user1, .user2]
            }
            if !list.contains(.user1) { list.append(.user1) }
            if !list.contains(.user2) { list.append(.user2) }
            return list
        }
        set {
            profileOrderRaw = newValue.map { $0.rawValue }.joined(separator: ",")
            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
        }
    }

    /// The list of profiles to display in the menu bar (respects user order and user2Enabled)
    public var activeMenuBarProfiles: [UserProfileID] {
        if user2Enabled {
            return configuredProfileOrder
        } else {
            return [.user1]
        }
    }

    public func name(for profile: UserProfileID) -> String {
        switch profile {
        case .user1:
            return p1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "User 1" : p1Name
        case .user2:
            return p2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "User 2" : p2Name
        }
    }

    public func username(for profile: UserProfileID) -> String {
        switch profile {
        case .user1: return p1Username
        case .user2: return p2Username
        }
    }

    public func region(for profile: UserProfileID) -> DexcomRegion {
        switch profile {
        case .user1: return DexcomRegion(rawValue: p1RegionRaw) ?? .us
        case .user2: return DexcomRegion(rawValue: p2RegionRaw) ?? .us
        }
    }

    public func colorIconEnabled(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1ColorIconEnabled
        case .user2: return p2ColorIconEnabled
        }
    }

    public func lowIconColor(for profile: UserProfileID) -> AppColorOption {
        switch profile {
        case .user1: return AppColorOption(rawValue: p1LowIconColorRaw) ?? .red
        case .user2: return AppColorOption(rawValue: p2LowIconColorRaw) ?? .blue
        }
    }

    public func normalIconColor(for profile: UserProfileID) -> NormalColorOption {
        switch profile {
        case .user1: return NormalColorOption(rawValue: p1NormalIconColorRaw) ?? .green
        case .user2: return NormalColorOption(rawValue: p2NormalIconColorRaw) ?? .green
        }
    }

    public func highIconColor(for profile: UserProfileID) -> AppColorOption {
        switch profile {
        case .user1: return AppColorOption(rawValue: p1HighIconColorRaw) ?? .orange
        case .user2: return AppColorOption(rawValue: p2HighIconColorRaw) ?? .purple
        }
    }

    public func showMenuBarTrendChart(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1ShowMenuBarTrendChart
        case .user2: return p2ShowMenuBarTrendChart
        }
    }

    public func showDeltaChange(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1ShowDeltaChange
        case .user2: return p2ShowDeltaChange
        }
    }

    public func showLogButton(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1ShowLogButton
        case .user2: return p2ShowLogButton
        }
    }

    public func currentReading(for profile: UserProfileID) -> GlucoseReading? {
        switch profile {
        case .user1: return p1CurrentReading
        case .user2: return p2CurrentReading
        }
    }

    public func recentReadings(for profile: UserProfileID) -> [GlucoseReading] {
        switch profile {
        case .user1: return p1RecentReadings
        case .user2: return p2RecentReadings
        }
    }

    public func errorMessage(for profile: UserProfileID) -> String? {
        switch profile {
        case .user1: return p1ErrorMessage
        case .user2: return p2ErrorMessage
        }
    }

    public func isLoading(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1IsLoading
        case .user2: return p2IsLoading
        }
    }

    public func lowThreshold(for profile: UserProfileID) -> Double {
        switch profile {
        case .user1: return p1LowThreshold
        case .user2: return p2LowThreshold
        }
    }

    public func highThreshold(for profile: UserProfileID) -> Double {
        switch profile {
        case .user1: return p1HighThreshold
        case .user2: return p2HighThreshold
        }
    }

    public func urgentLowThreshold(for profile: UserProfileID) -> Double {
        switch profile {
        case .user1: return p1UrgentLowThreshold
        case .user2: return p2UrgentLowThreshold
        }
    }

    public func urgentHighThreshold(for profile: UserProfileID) -> Double {
        switch profile {
        case .user1: return p1UrgentHighThreshold
        case .user2: return p2UrgentHighThreshold
        }
    }

    public func sensorTrackingEnabled(for profile: UserProfileID) -> Bool {
        switch profile {
        case .user1: return p1SensorTrackingEnabled
        case .user2: return p2SensorTrackingEnabled
        }
    }

    public func sensorModel(for profile: UserProfileID) -> DexcomSensorModel {
        switch profile {
        case .user1: return DexcomSensorModel(rawValue: p1SensorModelRaw) ?? .g7
        case .user2: return DexcomSensorModel(rawValue: p2SensorModelRaw) ?? .g7
        }
    }

    public func sensorStartTimestamp(for profile: UserProfileID) -> Double {
        switch profile {
        case .user1: return p1SensorStartTimestamp
        case .user2: return p2SensorStartTimestamp
        }
    }

    public func sensorStartDate(for profile: UserProfileID) -> Date? {
        let ts = sensorStartTimestamp(for: profile)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    public func isSensorExpired(for profile: UserProfileID) -> Bool {
        guard sensorTrackingEnabled(for: profile), let start = sensorStartDate(for: profile) else { return false }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed >= sensorModel(for: profile).lifespanSeconds
    }

    public func sensorTimeRemainingString(for profile: UserProfileID) -> String {
        guard sensorTrackingEnabled(for: profile), let start = sensorStartDate(for: profile) else {
            return "Tracking not started"
        }
        let total = sensorModel(for: profile).lifespanSeconds
        let elapsed = Date().timeIntervalSince(start)
        let remaining = total - elapsed

        if remaining <= 0 {
            return "Sensor is expired"
        }

        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }

    public func startNewSensor(for profile: UserProfileID) {
        let now = Date().timeIntervalSince1970
        switch profile {
        case .user1: p1SensorStartTimestamp = now
        case .user2: p2SensorStartTimestamp = now
        }
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    // MARK: - Active Profile Shorthands (for selected tab in MenuBarView)
    public var activeName: String { name(for: activeProfileId) }
    public var currentReading: GlucoseReading? { currentReading(for: activeProfileId) }
    public var recentReadings: [GlucoseReading] { recentReadings(for: activeProfileId) }
    public var isLoading: Bool { isLoading(for: activeProfileId) }
    public var errorMessage: String? { errorMessage(for: activeProfileId) }
    public var showLogButton: Bool { showLogButton(for: activeProfileId) }
    public var colorIconEnabled: Bool { colorIconEnabled(for: activeProfileId) }
    public var lowIconColor: AppColorOption { lowIconColor(for: activeProfileId) }
    public var normalIconColor: NormalColorOption { normalIconColor(for: activeProfileId) }
    public var highIconColor: AppColorOption { highIconColor(for: activeProfileId) }
    public var showMenuBarTrendChart: Bool { showMenuBarTrendChart(for: activeProfileId) }
    public var showDeltaChange: Bool { showDeltaChange(for: activeProfileId) }
    public var lowThreshold: Double { lowThreshold(for: activeProfileId) }
    public var highThreshold: Double { highThreshold(for: activeProfileId) }
    public var urgentLowThreshold: Double { urgentLowThreshold(for: activeProfileId) }
    public var urgentHighThreshold: Double { urgentHighThreshold(for: activeProfileId) }
    public var sensorTrackingEnabled: Bool {
        get { sensorTrackingEnabled(for: activeProfileId) }
        set {
            switch activeProfileId {
            case .user1: p1SensorTrackingEnabled = newValue
            case .user2: p2SensorTrackingEnabled = newValue
            }
        }
    }
    public var sensorModelRaw: String {
        get {
            switch activeProfileId {
            case .user1: return p1SensorModelRaw
            case .user2: return p2SensorModelRaw
            }
        }
        set {
            switch activeProfileId {
            case .user1: p1SensorModelRaw = newValue
            case .user2: p2SensorModelRaw = newValue
            }
        }
    }
    public var sensorStartTimestamp: Double {
        get { sensorStartTimestamp(for: activeProfileId) }
        set {
            switch activeProfileId {
            case .user1: p1SensorStartTimestamp = newValue
            case .user2: p2SensorStartTimestamp = newValue
            }
        }
    }
    public var sensorModel: DexcomSensorModel { sensorModel(for: activeProfileId) }
    public var sensorStartDate: Date? { sensorStartDate(for: activeProfileId) }
    public var isSensorExpired: Bool { isSensorExpired(for: activeProfileId) }
    public var sensorTimeRemainingString: String { sensorTimeRemainingString(for: activeProfileId) }
    public func startNewSensor() { startNewSensor(for: activeProfileId) }

    public var unit: GlucoseUnit {
        get { GlucoseUnit(rawValue: unitRaw) ?? .mgdL }
        set { unitRaw = newValue.rawValue }
    }

    public var visibleCategories: [DexcomEventType] {
        get {
            let names = visibleLogCategoriesRaw.split(separator: ",").map { String($0) }
            let list = names.compactMap { DexcomEventType(rawValue: $0) }
            return list.isEmpty ? DexcomEventType.allCases : list
        }
        set {
            visibleLogCategoriesRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    public func isCategoryVisible(_ cat: DexcomEventType) -> Bool {
        visibleCategories.contains(cat)
    }

    public func toggleCategoryVisibility(_ cat: DexcomEventType) {
        var current = visibleCategories
        if current.contains(cat) {
            if current.count > 1 {
                current.removeAll { $0 == cat }
            }
        } else {
            current.append(cat)
            current = DexcomEventType.allCases.filter { current.contains($0) }
        }
        visibleCategories = current
    }

    // MARK: - Passwords & Developer Credentials via Keychain
    public func getPassword(for profile: UserProfileID = .user1) -> String {
        let key = profile == .user1 ? "dexcom_password_user1" : "dexcom_password_user2"
        if let pass = KeychainHelper.shared.read(key: key) {
            return pass
        }
        if profile == .user1 {
            return KeychainHelper.shared.read(key: "dexcom_password") ?? ""
        }
        return ""
    }

    public func setPassword(_ pass: String, for profile: UserProfileID = .user1) {
        let key = profile == .user1 ? "dexcom_password_user1" : "dexcom_password_user2"
        _ = KeychainHelper.shared.save(key: key, value: pass)
        if profile == .user1 {
            _ = KeychainHelper.shared.save(key: "dexcom_password", value: pass)
        }
    }

    public func getDeveloperClientId() -> String {
        KeychainHelper.shared.read(key: "dexcom_developer_client_id") ?? "bA7kzyX0tWTRMsFZ10XbZtd5Al2VgLn7"
    }

    public func setDeveloperClientId(_ id: String) {
        _ = KeychainHelper.shared.save(key: "dexcom_developer_client_id", value: id)
    }

    public func getDeveloperClientSecret() -> String {
        KeychainHelper.shared.read(key: "dexcom_developer_client_secret") ?? "cppEPfU1EFBWrQOS"
    }

    public func setDeveloperClientSecret(_ secret: String) {
        _ = KeychainHelper.shared.save(key: "dexcom_developer_client_secret", value: secret)
    }

    public func getDeveloperRedirectUri() -> String {
        KeychainHelper.shared.read(key: "dexcom_developer_redirect_uri") ?? "http://localhost:8080/callback"
    }

    public func setDeveloperRedirectUri(_ uri: String) {
        _ = KeychainHelper.shared.save(key: "dexcom_developer_redirect_uri", value: uri)
    }

    // MARK: - Polling & Data Fetching
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchAllGlucoseData()
            }
        }
        Task {
            await fetchAllGlucoseData()
        }
    }

    public func fetchAllGlucoseData() async {
        await fetchGlucoseData(for: .user1)
        if user2Enabled {
            await fetchGlucoseData(for: .user2)
        }
    }

    public func fetchGlucoseData(for profile: UserProfileID = .user1) async {
        if demoMode {
            loadMockData(for: profile)
            return
        }

        let uname = username(for: profile)
        let pass = getPassword(for: profile)
        let reg = region(for: profile)

        guard !uname.isEmpty, !pass.isEmpty else {
            if profile == .user1 {
                self.p1ErrorMessage = "Configure credentials for \(name(for: .user1)) in Preferences."
            } else {
                self.p2ErrorMessage = "Configure credentials for \(name(for: .user2)) in Preferences."
            }
            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
            return
        }

        if profile == .user1 {
            self.p1IsLoading = true
            self.p1ErrorMessage = nil
        } else {
            self.p2IsLoading = true
            self.p2ErrorMessage = nil
        }

        let client = (profile == .user1) ? p1Client : p2Client

        do {
            let readings = try await client.fetchLatestReadings(
                username: uname,
                password: pass,
                region: reg,
                accountType: .sharer,
                minutes: 1440,
                maxCount: 72
            )

            if profile == .user1 {
                self.p1RecentReadings = readings
                self.p1CurrentReading = readings.first
                self.p1LastSuccessfulFetch = Date()
                self.p1RetryCount = 0
                self.p1IsLoading = false
                checkAlerts(for: self.p1CurrentReading, profile: .user1)
            } else {
                self.p2RecentReadings = readings
                self.p2CurrentReading = readings.first
                self.p2LastSuccessfulFetch = Date()
                self.p2RetryCount = 0
                self.p2IsLoading = false
                checkAlerts(for: self.p2CurrentReading, profile: .user2)
            }
            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
        } catch {
            if profile == .user1 {
                self.p1IsLoading = false
                self.p1ErrorMessage = error.localizedDescription
                scheduleRetry(for: .user1)
            } else {
                self.p2IsLoading = false
                self.p2ErrorMessage = error.localizedDescription
                scheduleRetry(for: .user2)
            }
            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
        }
    }

    private func scheduleRetry(for profile: UserProfileID) {
        let count = profile == .user1 ? (p1RetryCount + 1) : (p2RetryCount + 1)
        if profile == .user1 { p1RetryCount = count } else { p2RetryCount = count }

        let delay = min(15.0 * pow(2.0, Double(count - 1)), maxBackoffSeconds)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await fetchGlucoseData(for: profile)
        }
    }

    // MARK: - Simulation / Demo Mode
    public func loadMockData(for profile: UserProfileID = .user1) {
        let now = Date()
        var mock: [GlucoseReading] = []
        let baseValue = (profile == .user1) ? 118.0 : 134.0
        let trends: [GlucoseTrend] = [.flat, .fortyFiveUp, .singleUp, .flat, .fortyFiveDown]

        for i in 0..<288 {
            let offsetMinutes = Double(i * 5)
            let phase = profile == .user1 ? 0.0 : 2.0
            let val = baseValue + sin((Double(i) + phase) / 4.0) * 38.0 + cos((Double(i) + phase) / 12.0) * 20.0
            mock.append(GlucoseReading(
                value: max(40, round(val)),
                trend: trends[(i + (profile == .user1 ? 0 : 2)) % trends.count],
                timestamp: now.addingTimeInterval(-offsetMinutes * 60)
            ))
        }

        if profile == .user1 {
            self.p1RecentReadings = mock
            self.p1CurrentReading = mock.first
            self.p1LastSuccessfulFetch = now
            self.p1ErrorMessage = nil
            self.p1IsLoading = false
        } else {
            self.p2RecentReadings = mock
            self.p2CurrentReading = mock.first
            self.p2LastSuccessfulFetch = now
            self.p2ErrorMessage = nil
            self.p2IsLoading = false
        }
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    public func simulateUrgentLowAlert() {
        let reading = GlucoseReading(
            value: min(urgentLowThreshold - 7, 48.0),
            trend: .doubleDown,
            timestamp: Date()
        )
        if activeProfileId == .user1 {
            p1CurrentReading = reading
            p1RecentReadings.insert(reading, at: 0)
            p1LastSuccessfulFetch = Date()
        } else {
            p2CurrentReading = reading
            p2RecentReadings.insert(reading, at: 0)
            p2LastSuccessfulFetch = Date()
        }
        triggerUrgentAlert(
            title: "⚠️ [\(activeName)] URGENT LOW GLUCOSE: \(reading.formattedValue(unit: unit)) \(reading.trend.symbol)",
            body: "Simulated alert for \(activeName): Glucose is dangerously low (\(reading.formattedValue(unit: unit)) \(unit.rawValue)). Take fast-acting carbs immediately.",
            soundName: activeProfileId == .user1 ? p1UrgentLowSoundRaw : p2UrgentLowSoundRaw
        )
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    public func simulateUrgentHighAlert() {
        let reading = GlucoseReading(
            value: max(urgentHighThreshold + 15, 265.0),
            trend: .doubleUp,
            timestamp: Date()
        )
        if activeProfileId == .user1 {
            p1CurrentReading = reading
            p1RecentReadings.insert(reading, at: 0)
            p1LastSuccessfulFetch = Date()
        } else {
            p2CurrentReading = reading
            p2RecentReadings.insert(reading, at: 0)
            p2LastSuccessfulFetch = Date()
        }
        triggerUrgentAlert(
            title: "⚠️ [\(activeName)] URGENT HIGH GLUCOSE: \(reading.formattedValue(unit: unit)) \(reading.trend.symbol)",
            body: "Simulated alert for \(activeName): Glucose is very high (\(reading.formattedValue(unit: unit)) \(unit.rawValue)). Check ketones and administer insulin as directed.",
            soundName: activeProfileId == .user1 ? p1UrgentHighSoundRaw : p2UrgentHighSoundRaw
        )
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    public func simulateLowReading() {
        let reading = GlucoseReading(
            value: min(lowThreshold - 5, 64.0),
            trend: .singleDown,
            timestamp: Date()
        )
        if activeProfileId == .user1 {
            p1CurrentReading = reading
            p1RecentReadings.insert(reading, at: 0)
        } else {
            p2CurrentReading = reading
            p2RecentReadings.insert(reading, at: 0)
        }
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    public func simulateNormalReading() {
        let reading = GlucoseReading(
            value: 110.0,
            trend: .flat,
            timestamp: Date()
        )
        if activeProfileId == .user1 {
            p1CurrentReading = reading
            p1RecentReadings.insert(reading, at: 0)
        } else {
            p2CurrentReading = reading
            p2RecentReadings.insert(reading, at: 0)
        }
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    public func simulateHighReading() {
        let reading = GlucoseReading(
            value: max(highThreshold + 10, 210.0),
            trend: .singleUp,
            timestamp: Date()
        )
        if activeProfileId == .user1 {
            p1CurrentReading = reading
            p1RecentReadings.insert(reading, at: 0)
        } else {
            p2CurrentReading = reading
            p2RecentReadings.insert(reading, at: 0)
        }
        NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
    }

    // MARK: - Delta & Category Helpers per Profile
    public func currentDeltaMgDl(for profile: UserProfileID) -> Double? {
        let list = recentReadings(for: profile)
        guard list.count >= 2 else { return nil }
        return list[0].value - list[1].value
    }

    public func formattedDelta(for profile: UserProfileID, unit: GlucoseUnit) -> String? {
        guard let delta = currentDeltaMgDl(for: profile) else { return nil }
        let sign = delta > 0 ? "+" : (delta < 0 ? "-" : "±")
        let absVal = abs(delta)
        switch unit {
        case .mgdL:
            return "(\(sign)\(Int(round(absVal))))"
        case .mmolL:
            let mmol = absVal / 18.0182
            return String(format: "(%@%.1f)", sign, mmol)
        }
    }

    /// Menu bar title snippet for a single profile (excluding name, per instruction!)
    public func menuBarTitle(for profile: UserProfileID) -> String {
        guard let reading = currentReading(for: profile) else {
            return demoMode ? "[SIM] –" : "–"
        }
        let formatted = reading.formattedValue(unit: unit)
        let prefix = (demoMode && profile == activeMenuBarProfiles.first) ? "[SIM] " : ""

        if showDeltaChange(for: profile), let deltaStr = formattedDelta(for: profile, unit: unit) {
            return "\(prefix)\(formatted) \(deltaStr) \(reading.trend.symbol)"
        }
        return "\(prefix)\(formatted) \(reading.trend.symbol)"
    }

    public func category(for reading: GlucoseReading, profile: UserProfileID? = nil) -> GlucoseCategory {
        let targetProfile = profile ?? activeProfileId
        return reading.category(
            lowThreshold: lowThreshold(for: targetProfile),
            highThreshold: highThreshold(for: targetProfile),
            urgentLowThreshold: urgentLowThreshold(for: targetProfile),
            urgentHighThreshold: urgentHighThreshold(for: targetProfile)
        )
    }

    // MARK: - Alerts
    private func checkAlerts(for reading: GlucoseReading?, profile: UserProfileID) {
        guard let reading = reading else { return }
        let notifEnabled = (profile == .user1) ? p1NotificationsEnabled : p2NotificationsEnabled
        guard notifEnabled else { return }

        let lastReadingId = (profile == .user1) ? p1LastAlertedReadingId : p2LastAlertedReadingId
        if lastReadingId == reading.id { return }

        let lastTime = (profile == .user1) ? p1LastAlertTime : p2LastAlertTime
        if let last = lastTime, Date().timeIntervalSince(last) < 300 {
            return
        }

        let urgentLow = urgentLowThreshold(for: profile)
        let urgentHigh = urgentHighThreshold(for: profile)
        let soundLow = (profile == .user1) ? p1UrgentLowSoundRaw : p2UrgentLowSoundRaw
        let soundHigh = (profile == .user1) ? p1UrgentHighSoundRaw : p2UrgentHighSoundRaw
        let profileDisplayName = name(for: profile)

        if reading.value <= urgentLow {
            if profile == .user1 {
                p1LastAlertedReadingId = reading.id
                p1LastAlertTime = Date()
            } else {
                p2LastAlertedReadingId = reading.id
                p2LastAlertTime = Date()
            }
            triggerUrgentAlert(
                title: "⚠️ [\(profileDisplayName)] URGENT LOW GLUCOSE: \(reading.formattedValue(unit: unit)) \(reading.trend.symbol)",
                body: "Current reading for \(profileDisplayName) is \(reading.formattedValue(unit: unit)) \(unit.rawValue). Take fast-acting carbs immediately.",
                soundName: soundLow
            )
        } else if reading.value >= urgentHigh {
            if profile == .user1 {
                p1LastAlertedReadingId = reading.id
                p1LastAlertTime = Date()
            } else {
                p2LastAlertedReadingId = reading.id
                p2LastAlertTime = Date()
            }
            triggerUrgentAlert(
                title: "⚠️ [\(profileDisplayName)] URGENT HIGH GLUCOSE: \(reading.formattedValue(unit: unit)) \(reading.trend.symbol)",
                body: "Current reading for \(profileDisplayName) is \(reading.formattedValue(unit: unit)) \(unit.rawValue). Check ketones and insulin as directed.",
                soundName: soundHigh
            )
        }
    }

    public func triggerUrgentAlert(title: String, body: String, soundName: String) {
        if let sound = NSSound(named: soundName) ?? NSSound(named: "Ping") {
            sound.play()
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                NSLog("[DexcomMenuBar] Notification error: %@", err.localizedDescription)
            }
        }
    }
}
