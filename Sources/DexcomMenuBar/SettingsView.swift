import SwiftUI

public struct SettingsView: View {
    @ObservedObject var manager: GlucoseManager
    @State private var p1PasswordInput: String = ""
    @State private var p2PasswordInput: String = ""
    @State private var redirectUriInput: String = ""
    @State private var showingCustomRedirect: Bool = false
    @State private var saveStatus: String? = nil
    @Environment(\.dismiss) private var dismiss

    // Accordion expansion states
    @State private var isProfilesExpanded: Bool = true
    @State private var isUser1Expanded: Bool = true
    @State private var isUser2Expanded: Bool = false
    @State private var isAlertsExpanded: Bool = false
    @State private var isCloudSyncExpanded: Bool = false
    @State private var isSimExpanded: Bool = false

    public init(manager: GlucoseManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "drop.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dexcom Preferences")
                        .font(.system(size: 15, weight: .bold))
                    Text("Multi-user profiles, menu bar behavior, colors & sensor countdowns")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.4)

            // Scrollable Accordion Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    
                    // SECTION 1: Profiles & Display Order
                    DisclosureGroup(
                        isExpanded: $isProfilesExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 12) {
                                // Enable Second User Toggle
                                Toggle(isOn: $manager.user2Enabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable Multi-User Tracking (Second Login)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text("Monitors two independent Dexcom CGM accounts simultaneously with independent menu bar widgets.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .onChange(of: manager.user2Enabled) { _ in
                                    NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
                                }

                                Divider().opacity(0.3)

                                // User Display Names
                                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                                    GridRow {
                                        Text("User 1 Name:")
                                            .font(.caption)
                                            .frame(width: 120, alignment: .trailing)
                                        TextField("e.g. Sarah / Me", text: $manager.p1Name)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.caption)
                                    }

                                    if manager.user2Enabled {
                                        GridRow {
                                            Text("User 2 Name:")
                                                .font(.caption)
                                                .frame(width: 120, alignment: .trailing)
                                            TextField("e.g. Dad / Kid / Partner", text: $manager.p2Name)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.caption)
                                        }
                                    }
                                }

                                // Menu Bar Display Order
                                if manager.user2Enabled {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Menu Bar Display Order:")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Button("Swap Order") {
                                                withAnimation {
                                                    var order = manager.configuredProfileOrder
                                                    order.reverse()
                                                    manager.configuredProfileOrder = order
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }

                                        HStack(spacing: 6) {
                                            ForEach(Array(manager.configuredProfileOrder.enumerated()), id: \.offset) { idx, pid in
                                                HStack(spacing: 5) {
                                                    Text("#\(idx + 1)")
                                                        .font(.system(size: 9.5, weight: .bold))
                                                        .foregroundColor(.secondary)
                                                    Circle()
                                                        .fill(manager.lowIconColor(for: pid).color)
                                                        .frame(width: 7, height: 7)
                                                    Text(manager.name(for: pid))
                                                        .font(.system(size: 11, weight: .semibold))
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                                )

                                                if idx < manager.configuredProfileOrder.count - 1 {
                                                    Image(systemName: "arrow.right")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        Text("Note: User names appear inside the popout menu header, never in the menu bar itself.")
                                            .font(.system(size: 9.5))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.06)))
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.accentColor)
                                Text("Profiles & Order Configuration")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                if manager.user2Enabled {
                                    Text("2 Users Active")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    )
                    .disclosureCard()

                    // SECTION 2: User 1 Preferences
                    DisclosureGroup(
                        isExpanded: $isUser1Expanded,
                        content: {
                            UserProfileSettingsCard(
                                profileId: .user1,
                                manager: manager,
                                passwordInput: $p1PasswordInput
                            )
                        },
                        label: {
                            HStack {
                                Circle().fill(manager.lowIconColor(for: .user1).color).frame(width: 8, height: 8)
                                Text("\(manager.name(for: .user1)) Settings")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(manager.p1Username.isEmpty ? "Not configured" : manager.p1Username)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .disclosureCard()

                    // SECTION 3: User 2 Preferences (if enabled)
                    if manager.user2Enabled {
                        DisclosureGroup(
                            isExpanded: $isUser2Expanded,
                            content: {
                                UserProfileSettingsCard(
                                    profileId: .user2,
                                    manager: manager,
                                    passwordInput: $p2PasswordInput
                                )
                            },
                            label: {
                                HStack {
                                    Circle().fill(manager.lowIconColor(for: .user2).color).frame(width: 8, height: 8)
                                    Text("\(manager.name(for: .user2)) Settings")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(manager.p2Username.isEmpty ? "Not configured" : manager.p2Username)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                        .disclosureCard()
                    }

                    // SECTION 4: Thresholds & Alert Sounds
                    DisclosureGroup(
                        isExpanded: $isAlertsExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $manager.syncTargetsWithDexcom) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sync Target Ranges with Other Devices & Dexcom Account")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("Automatically aligns normal target ranges (70 - 180 mg/dL) with your Dexcom CGM app profile.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)

                                Divider().opacity(0.3)

                                // Global Glucose Units
                                HStack {
                                    Text("Display Unit:")
                                        .font(.caption)
                                        .frame(width: 120, alignment: .trailing)
                                    Picker("", selection: $manager.unitRaw) {
                                        ForEach(GlucoseUnit.allCases) { u in
                                            Text(u.rawValue).tag(u.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 160)
                                }

                                Divider().opacity(0.3)

                                // User 1 Alert Sounds & Limits
                                Text("Alerts for \(manager.name(for: .user1)):")
                                    .font(.caption)
                                    .fontWeight(.bold)

                                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                                    GridRow {
                                        Text("Urgent Low Alert:")
                                            .font(.caption)
                                            .frame(width: 120, alignment: .trailing)
                                        HStack(spacing: 6) {
                                            Stepper(value: $manager.p1UrgentLowThreshold, in: 40...80, step: 5) {
                                                Text("≤ \(manager.unit.format(mgdL: manager.p1UrgentLowThreshold)) \(manager.unit.rawValue)")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.red)
                                                    .frame(width: 80, alignment: .leading)
                                            }
                                            Picker("", selection: $manager.p1UrgentLowSoundRaw) {
                                                ForEach(AlertSoundOption.allCases) { s in Text(s.displayName).tag(s.rawValue) }
                                            }
                                            .labelsHidden()
                                            Button { manager.triggerUrgentAlert(title: "Test", body: "Sound", soundName: manager.p1UrgentLowSoundRaw) } label: {
                                                Image(systemName: "speaker.wave.2.fill").font(.caption)
                                            }.buttonStyle(.bordered).controlSize(.mini)
                                        }
                                    }

                                    GridRow {
                                        Text("Urgent High Alert:")
                                            .font(.caption)
                                            .frame(width: 120, alignment: .trailing)
                                        HStack(spacing: 6) {
                                            Stepper(value: $manager.p1UrgentHighThreshold, in: 200...400, step: 10) {
                                                Text("≥ \(manager.unit.format(mgdL: manager.p1UrgentHighThreshold)) \(manager.unit.rawValue)")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.red)
                                                    .frame(width: 80, alignment: .leading)
                                            }
                                            Picker("", selection: $manager.p1UrgentHighSoundRaw) {
                                                ForEach(AlertSoundOption.allCases) { s in Text(s.displayName).tag(s.rawValue) }
                                            }
                                            .labelsHidden()
                                            Button { manager.triggerUrgentAlert(title: "Test", body: "Sound", soundName: manager.p1UrgentHighSoundRaw) } label: {
                                                Image(systemName: "speaker.wave.2.fill").font(.caption)
                                            }.buttonStyle(.bordered).controlSize(.mini)
                                        }
                                    }
                                }

                                if manager.user2Enabled {
                                    Divider().opacity(0.3)
                                    Text("Alerts for \(manager.name(for: .user2)):")
                                        .font(.caption)
                                        .fontWeight(.bold)

                                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                                        GridRow {
                                            Text("Urgent Low Alert:")
                                                .font(.caption)
                                                .frame(width: 120, alignment: .trailing)
                                            HStack(spacing: 6) {
                                                Stepper(value: $manager.p2UrgentLowThreshold, in: 40...80, step: 5) {
                                                    Text("≤ \(manager.unit.format(mgdL: manager.p2UrgentLowThreshold)) \(manager.unit.rawValue)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.red)
                                                        .frame(width: 80, alignment: .leading)
                                                }
                                                Picker("", selection: $manager.p2UrgentLowSoundRaw) {
                                                    ForEach(AlertSoundOption.allCases) { s in Text(s.displayName).tag(s.rawValue) }
                                                }
                                                .labelsHidden()
                                                Button { manager.triggerUrgentAlert(title: "Test", body: "Sound", soundName: manager.p2UrgentLowSoundRaw) } label: {
                                                    Image(systemName: "speaker.wave.2.fill").font(.caption)
                                                }.buttonStyle(.bordered).controlSize(.mini)
                                            }
                                        }

                                        GridRow {
                                            Text("Urgent High Alert:")
                                                .font(.caption)
                                                .frame(width: 120, alignment: .trailing)
                                            HStack(spacing: 6) {
                                                Stepper(value: $manager.p2UrgentHighThreshold, in: 200...400, step: 10) {
                                                    Text("≥ \(manager.unit.format(mgdL: manager.p2UrgentHighThreshold)) \(manager.unit.rawValue)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.red)
                                                        .frame(width: 80, alignment: .leading)
                                                }
                                                Picker("", selection: $manager.p2UrgentHighSoundRaw) {
                                                    ForEach(AlertSoundOption.allCases) { s in Text(s.displayName).tag(s.rawValue) }
                                                }
                                                .labelsHidden()
                                                Button { manager.triggerUrgentAlert(title: "Test", body: "Sound", soundName: manager.p2UrgentHighSoundRaw) } label: {
                                                    Image(systemName: "speaker.wave.2.fill").font(.caption)
                                                }.buttonStyle(.bordered).controlSize(.mini)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.orange)
                                Text("Alert Thresholds & Sounds")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    )
                    .disclosureCard()

                    // SECTION 5: Dexcom Cloud 1-Click Sync (OAuth2)
                    DisclosureGroup(
                        isExpanded: $isCloudSyncExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(DexcomOAuthManager.shared.isAuthorized ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: DexcomOAuthManager.shared.isAuthorized ? "checkmark.circle.fill" : "cloud.badge.chevron.backward.fill")
                                            .foregroundColor(DexcomOAuthManager.shared.isAuthorized ? .green : .accentColor)
                                            .font(.system(size: 14, weight: .bold))
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Official Dexcom v3 Developer OAuth2")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                        Text(DexcomOAuthManager.shared.isAuthorized ? "Connected & authorized to sync events to Clarity" : "Not connected (events saved locally on Mac only)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if DexcomOAuthManager.shared.isAuthorized {
                                        Text("Active")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                }

                                if !DexcomOAuthManager.shared.isAuthorized {
                                    HStack {
                                        Text("Redirect URI:")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button(action: {
                                            withAnimation { showingCustomRedirect.toggle() }
                                        }) {
                                            Text(showingCustomRedirect ? "Hide" : "Edit URI")
                                                .font(.system(size: 9.5))
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if showingCustomRedirect {
                                        HStack {
                                            TextField("e.g. http://localhost:8080/callback", text: $redirectUriInput)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 11, design: .monospaced))
                                            Button("Set") {
                                                let cleaned = redirectUriInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !cleaned.isEmpty {
                                                    manager.setDeveloperRedirectUri(cleaned)
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    } else {
                                        Text(redirectUriInput.isEmpty ? manager.getDeveloperRedirectUri() : redirectUriInput)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }

                                    Button(action: {
                                        let uri = redirectUriInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? manager.getDeveloperRedirectUri() : redirectUriInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                        DexcomOAuthManager.shared.start1ClickAuthorization(
                                            clientId: manager.getDeveloperClientId(),
                                            clientSecret: manager.getDeveloperClientSecret(),
                                            redirectURI: uri
                                        )
                                    }) {
                                        HStack(spacing: 6) {
                                            if DexcomOAuthManager.shared.isAuthenticating {
                                                ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                                            } else {
                                                Image(systemName: "safari.fill").font(.system(size: 13, weight: .bold))
                                            }
                                            Text("1-Click Connect with Dexcom")
                                                .font(.system(size: 12.5, weight: .bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button("Disconnect Dexcom Cloud") {
                                        DexcomOAuthManager.shared.disconnect()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundColor(.blue)
                                Text("Dexcom Cloud & Clarity Sync (OAuth2)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    )
                    .disclosureCard()

                    // SECTION 6: Simulation / Testing
                    DisclosureGroup(
                        isExpanded: $isSimExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Simulation Mode:")
                                        .font(.caption)
                                    Toggle("", isOn: $manager.demoMode)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        .onChange(of: manager.demoMode) { isDemo in
                                            if isDemo {
                                                manager.loadMockData(for: .user1)
                                                if manager.user2Enabled { manager.loadMockData(for: .user2) }
                                            }
                                        }
                                }

                                if manager.demoMode {
                                    HStack(spacing: 6) {
                                        Button("Urgent Low (48)") { manager.simulateUrgentLowAlert() }
                                            .buttonStyle(.borderedProminent).tint(.red).controlSize(.mini)
                                        Button("Low (64)") { manager.simulateLowReading() }
                                            .buttonStyle(.bordered).controlSize(.mini)
                                        Button("Normal (110)") { manager.simulateNormalReading() }
                                            .buttonStyle(.bordered).controlSize(.mini)
                                        Button("Urgent High (265)") { manager.simulateUrgentHighAlert() }
                                            .buttonStyle(.borderedProminent).tint(.red).controlSize(.mini)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        },
                        label: {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(.purple)
                                Text("Simulation & Testing Mode")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    )
                    .disclosureCard()

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider().opacity(0.4)

            // Feedback Status & Footer Buttons
            HStack {
                if let status = saveStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save & Sync") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 550, height: 600)
        .background(.ultraThinMaterial)
        .onAppear {
            self.p1PasswordInput = manager.getPassword(for: .user1)
            self.p2PasswordInput = manager.getPassword(for: .user2)
            self.redirectUriInput = manager.getDeveloperRedirectUri()
        }
    }

    private func saveSettings() {
        if !p1PasswordInput.isEmpty {
            manager.setPassword(p1PasswordInput, for: .user1)
        }
        if !p2PasswordInput.isEmpty {
            manager.setPassword(p2PasswordInput, for: .user2)
        }

        saveStatus = "Connecting & refreshing readings..."
        Task {
            await manager.fetchAllGlucoseData()
            saveStatus = "Saved successfully!"
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        }
    }
}

/// Helper card rendering settings for a single user profile (not mirrored)
struct UserProfileSettingsCard: View {
    let profileId: UserProfileID
    @ObservedObject var manager: GlucoseManager
    @Binding var passwordInput: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Credentials
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Dexcom Username:")
                        .font(.caption)
                        .frame(width: 120, alignment: .trailing)
                    if profileId == .user1 {
                        TextField("Primary Wearer Username / Phone", text: $manager.p1Username)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Second Wearer Username / Phone", text: $manager.p2Username)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                GridRow {
                    Text("Password:")
                        .font(.caption)
                        .frame(width: 120, alignment: .trailing)
                    SecureField("Dexcom Account Password", text: $passwordInput)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Dexcom Region:")
                        .font(.caption)
                        .frame(width: 120, alignment: .trailing)
                    if profileId == .user1 {
                        Picker("", selection: $manager.p1RegionRaw) {
                            ForEach(DexcomRegion.allCases) { r in Text(r.rawValue).tag(r.rawValue) }
                        }
                        .labelsHidden()
                    } else {
                        Picker("", selection: $manager.p2RegionRaw) {
                            ForEach(DexcomRegion.allCases) { r in Text(r.rawValue).tag(r.rawValue) }
                        }
                        .labelsHidden()
                    }
                }
            }

            Divider().opacity(0.3)

            // Independent Menu Bar Behaviors (Unmirrored)
            Text("Independent Menu Bar Behaviors:")
                .font(.caption)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                if profileId == .user1 {
                    Toggle("Show Trend Bar Chart to Right of Reading", isOn: $manager.p1ShowMenuBarTrendChart)
                        .font(.caption)
                        .onChange(of: manager.p1ShowMenuBarTrendChart) { _ in
                            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
                        }

                    Toggle("Show Rate-of-Change Delta (e.g. 118 (+5) →)", isOn: $manager.p1ShowDeltaChange)
                        .font(.caption)
                        .onChange(of: manager.p1ShowDeltaChange) { _ in
                            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
                        }

                    Toggle("Show '+ Log Event' Button in Popover for this User", isOn: $manager.p1ShowLogButton)
                        .font(.caption)
                } else {
                    Toggle("Show Trend Bar Chart to Right of Reading", isOn: $manager.p2ShowMenuBarTrendChart)
                        .font(.caption)
                        .onChange(of: manager.p2ShowMenuBarTrendChart) { _ in
                            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
                        }

                    Toggle("Show Rate-of-Change Delta (e.g. 118 (+5) →)", isOn: $manager.p2ShowDeltaChange)
                        .font(.caption)
                        .onChange(of: manager.p2ShowDeltaChange) { _ in
                            NotificationCenter.default.post(name: .glucoseDataUpdated, object: nil)
                        }

                    Toggle("Show '+ Log Event' Button in Popover for this User", isOn: $manager.p2ShowLogButton)
                        .font(.caption)
                }
            }

            Divider().opacity(0.3)

            // Droplet Color Customization
            Text("Droplet Icon Colors:")
                .font(.caption)
                .fontWeight(.bold)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Low Droplet Color:")
                        .font(.caption)
                        .frame(width: 120, alignment: .trailing)
                    HStack(spacing: 6) {
                        Circle().fill(manager.lowIconColor(for: profileId).color).frame(width: 12, height: 12)
                        if profileId == .user1 {
                            Picker("", selection: $manager.p1LowIconColorRaw) {
                                ForEach(AppColorOption.allCases) { opt in Text(opt.rawValue).tag(opt.rawValue) }
                            }
                            .labelsHidden()
                        } else {
                            Picker("", selection: $manager.p2LowIconColorRaw) {
                                ForEach(AppColorOption.allCases) { opt in Text(opt.rawValue).tag(opt.rawValue) }
                            }
                            .labelsHidden()
                        }
                    }
                }

                GridRow {
                    Text("High Droplet Color:")
                        .font(.caption)
                        .frame(width: 120, alignment: .trailing)
                    HStack(spacing: 6) {
                        Circle().fill(manager.highIconColor(for: profileId).color).frame(width: 12, height: 12)
                        if profileId == .user1 {
                            Picker("", selection: $manager.p1HighIconColorRaw) {
                                ForEach(AppColorOption.allCases) { opt in Text(opt.rawValue).tag(opt.rawValue) }
                            }
                            .labelsHidden()
                        } else {
                            Picker("", selection: $manager.p2HighIconColorRaw) {
                                ForEach(AppColorOption.allCases) { opt in Text(opt.rawValue).tag(opt.rawValue) }
                            }
                            .labelsHidden()
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Sensor Lifespan Tracker
            Text("Sensor Lifespan Tracker:")
                .font(.caption)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                if profileId == .user1 {
                    Toggle("Enable Lifespan Countdown Tracker", isOn: $manager.p1SensorTrackingEnabled)
                        .font(.caption)
                    if manager.p1SensorTrackingEnabled {
                        HStack {
                            Text("Model:")
                                .font(.caption)
                            Picker("", selection: $manager.p1SensorModelRaw) {
                                ForEach(DexcomSensorModel.allCases) { m in Text(m.rawValue).tag(m.rawValue) }
                            }
                            .labelsHidden()

                            Spacer()

                            Button("Start New Sensor") {
                                manager.startNewSensor(for: .user1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Text("Status: \(manager.sensorTimeRemainingString(for: .user1))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Toggle("Enable Lifespan Countdown Tracker", isOn: $manager.p2SensorTrackingEnabled)
                        .font(.caption)
                    if manager.p2SensorTrackingEnabled {
                        HStack {
                            Text("Model:")
                                .font(.caption)
                            Picker("", selection: $manager.p2SensorModelRaw) {
                                ForEach(DexcomSensorModel.allCases) { m in Text(m.rawValue).tag(m.rawValue) }
                            }
                            .labelsHidden()

                            Spacer()

                            Button("Start New Sensor") {
                                manager.startNewSensor(for: .user2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Text("Status: \(manager.sensorTimeRemainingString(for: .user2))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

extension View {
    func disclosureCard() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}
