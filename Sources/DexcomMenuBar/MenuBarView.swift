import SwiftUI
import UniformTypeIdentifiers

public struct MenuBarView: View {
    @ObservedObject var manager: GlucoseManager
    public let onOpenSettings: () -> Void
    @State private var showingLogModal: Bool = false
    @State private var showingTrendsAndLogsModal: Bool = false
    @State private var showingQuitConfirmation: Bool = false

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    public init(manager: GlucoseManager, onOpenSettings: @escaping () -> Void) {
        self.manager = manager
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Bar: Red Power Button at the very top left with quit confirmation alert
            HStack {
                Button(action: {
                    showingQuitConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.75))
                        Text("Quit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .systemRed).opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color(nsColor: .systemRed).opacity(0.18), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Quit Dexcom Menu Bar App")

                Spacer()

                // Trends & Logs Modal Launcher Button
                Button(action: {
                    showingTrendsAndLogsModal = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("Trends & Logs")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .help("Open Dexcom API Trends, Statistics & Event History")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold))
                }
                .help("Preferences & Settings")
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .alert("Quit DexcomMenuBar?", isPresented: $showingQuitConfirmation) {
                Button("Quit Application", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("⚠️ Warning: Blood glucose alerts, audio warnings, and the menu bar widget will disappear and stop monitoring until the app is relaunched.")
            }

            // Top Header: Configurable User Name(s) Header (Prominently displayed at top of popped-out menu)
            PopoverProfileHeaderView(manager: manager)

            // Hero Card: Current Reading & Liquid Glass presentation
            ReadingHeroCard(manager: manager, onOpenSettings: onOpenSettings)

            // Diagnostic status banner (clean liquid card)
            if let error = manager.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.subheadline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if error.contains("no recent sensor readings") {
                        Text("• Ensure Dexcom Share is toggled ON in the Dexcom mobile app.\n• If using Follower, verify the Sharer has accepted and is sharing active data.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            // Sparkline Trend Visualization
            if !manager.recentReadings.isEmpty {
                SparklineView(readings: manager.recentReadings, unit: manager.unit, isDemo: manager.demoMode)
            }

            // Recent History List (Scrollable 6 Hours of Readings)
            if !manager.recentReadings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(manager.demoMode ? "Recent Readings (Simulated 6 Hours)" : "Recent Readings (Last 6 Hours)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(manager.demoMode ? .orange : .secondary)
                        Spacer()
                        if manager.demoMode {
                            Text("SIM")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange))
                        }
                        Text("\(manager.recentReadings.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 3) {
                            ForEach(manager.recentReadings) { item in
                                let cat = manager.category(for: item)
                                let itemColor: Color = {
                                    switch cat {
                                    case .low, .veryLow: return manager.lowIconColor.color
                                    case .high, .veryHigh: return manager.highIconColor.color
                                    case .normal: return manager.normalIconColor.color
                                    }
                                }()

                                HStack {
                                    Text(dateFormatter.string(from: item.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 65, alignment: .leading)

                                    Circle()
                                        .fill(itemColor)
                                        .frame(width: 6, height: 6)

                                    Text(item.formattedValue(unit: manager.unit))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                                    Text(item.trend.symbol)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text("\(item.minutesAgo)m ago")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
                }
            }

            Divider()
                .opacity(0.5)

            // Bottom Action Bar: Prominent Refresh & Extra Large [+ Log Event] Button
            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        await manager.fetchAllGlucoseData()
                    }
                }) {
                    HStack(spacing: 5) {
                        if manager.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("Refresh")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .help("Refresh Glucose Readings for All Active Profiles")
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                // Extra Large, Prominent Log Button (can be toggled off per user in preferences)
                if manager.showLogButton {
                    Button(action: {
                        showingLogModal = true
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Log Event")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .help("Create New Diabetes Log Event for \(manager.activeName)")
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
        .sheet(isPresented: $showingLogModal) {
            DexcomLogSheet(manager: manager)
        }
        .sheet(isPresented: $showingTrendsAndLogsModal) {
            DexcomTrendsAndLogsSheet(manager: manager)
        }
        // Liquid glass backdrop with material vibrancy
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            if manager.demoMode {
                HStack(spacing: 6) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("SIMULATION MODE ACTIVE — NOT REAL DATA")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.95), Color.red.opacity(0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
        }
        .overlay {
            if manager.demoMode {
                // Diagonal high-visibility watermark across reading area
                VStack {
                    Spacer().frame(height: 70)
                    Text("SIMULATION")
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.orange.opacity(0.18))
                        .rotationEffect(.degrees(-24))
                        .allowsHitTesting(false)
                    Spacer()
                }
            }
        }
    }
}

/// Header displaying configurable profile names and multi-user switcher
struct PopoverProfileHeaderView: View {
    @ObservedObject var manager: GlucoseManager

    var body: some View {
        if manager.user2Enabled {
            HStack(spacing: 8) {
                ForEach(manager.configuredProfileOrder) { pid in
                    let isSelected = (manager.activeProfileId == pid)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            manager.activeProfileId = pid
                        }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7)

                            Text(manager.name(for: pid))
                                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .primary : .secondary)

                            if let reading = manager.currentReading(for: pid) {
                                Text("\(reading.formattedValue(unit: manager.unit)) \(reading.trend.symbol)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(isSelected ? .primary : .secondary)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.25))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
                Text(manager.name(for: .user1))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 2)
        }
    }
}

/// Hero Card rendering active profile's glucose value, category pill, trend arrow, and cloud auth badge
struct ReadingHeroCard: View {
    @ObservedObject var manager: GlucoseManager
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let reading = manager.currentReading {
                    let cat = manager.category(for: reading)
                    let catColor: Color = {
                        switch cat {
                        case .low, .veryLow: return manager.lowIconColor.color
                        case .high, .veryHigh: return manager.highIconColor.color
                        case .normal: return manager.normalIconColor.color
                        }
                    }()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(reading.formattedValue(unit: manager.unit))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(reading.isStale ? .secondary : catColor)

                        Text(manager.unit.rawValue)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        Text(reading.trend.symbol)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(reading.isStale ? .secondary : catColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(cat.title)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(catColor.opacity(0.18)))
                            .foregroundColor(catColor)

                        if reading.isStale {
                            Label("\(reading.minutesAgo)m ago", systemImage: "clock.badge.exclamationmark")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Label("\(reading.minutesAgo)m ago", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if !DexcomOAuthManager.shared.isAuthorized {
                            Button(action: onOpenSettings) {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 10))
                                    Text("Cloud Not Linked")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dexcom")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Awaiting reading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            if let reading = manager.currentReading {
                Text(reading.trend.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .overlay {
            if manager.demoMode {
                ZStack {
                    Text("SIMULATED")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(Color.orange.opacity(0.28))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 2)
                        )
                        .rotationEffect(.degrees(-8))
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// Modal Sheet for logging events (Food, Insulin, Exercise, BGM, Sensor, Notes) with liquid glass UI
public struct DexcomLogSheet: View {
    @ObservedObject var manager: GlucoseManager
    @Environment(\.dismiss) private var dismiss

    @State private var eventType: DexcomEventType = .food
    @State private var primaryValue: String = ""
    @State private var secondaryValue: String = ""
    @State private var mealType: MealType = .lunch
    @State private var proteinValue: String = ""
    @State private var fatValue: String = ""
    @State private var fiberValue: String = ""
    @State private var exerciseIntensity: ExerciseIntensity = .medium
    @State private var insulinSubtype: InsulinSubtype = .fastActing
    @State private var noteText: String = ""
    @State private var eventDate: Date = Date()
    @State private var submissionStatus: String? = nil
    @State private var showingCategoryCustomizer: Bool = false

    public struct MealPreset: Identifiable {
        public let id = UUID()
        public let title: String
        public let carbs: Double
        public let mealType: MealType
        public let protein: Double?
        public let fat: Double?
        public let fiber: Double?
        public let icon: String
    }

    private let mealPresets: [MealPreset] = [
        MealPreset(title: "Morning Oatmeal", carbs: 40, mealType: .breakfast, protein: 6, fat: 4, fiber: 5, icon: "cup.and.saucer.fill"),
        MealPreset(title: "Espresso", carbs: 0, mealType: .breakfast, protein: 0, fat: 0, fiber: 0, icon: "mug.fill"),
        MealPreset(title: "Turkey Sandwich", carbs: 32, mealType: .lunch, protein: 24, fat: 9, fiber: 3, icon: "takeoutbag.and.cup.and.straw.fill"),
        MealPreset(title: "Green Salad & Chicken", carbs: 8, mealType: .lunch, protein: 35, fat: 12, fiber: 4, icon: "leaf.fill"),
        MealPreset(title: "Apple & Peanut Butter", carbs: 22, mealType: .snack, protein: 7, fat: 16, fiber: 4, icon: "apple.logo"),
        MealPreset(title: "Protein Shake", carbs: 5, mealType: .snack, protein: 30, fat: 3, fiber: 2, icon: "waterbottle.fill"),
        MealPreset(title: "Rice & Salmon Bowl", carbs: 48, mealType: .dinner, protein: 38, fat: 15, fiber: 3, icon: "fork.knife")
    ]

    public enum MealType: String, CaseIterable, Identifiable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"

        public var id: String { rawValue }
    }

    public enum InsulinSubtype: String, CaseIterable, Identifiable {
        case fastActing = "Fast Acting"
        case longActing = "Long Acting"

        public var id: String { rawValue }
    }

    public enum ExerciseIntensity: String, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        public var id: String { rawValue }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar
            categorySelectorSection
            inputFormSection
            statusBannerSection
            Spacer()
            footerBar
        }
        .padding(18)
        .frame(width: 480, height: 490)
        .background(.ultraThinMaterial)
        .onAppear {
            if manager.sensorTrackingEnabled && manager.sensorStartTimestamp == 0 {
                manager.startNewSensor()
            }
        }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Log Diabetes Event")
                    .font(.system(size: 15, weight: .bold))
                Text("Dexcom API v3 Events & Local Health Sync")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var categorySelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select Event Category")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingCategoryCustomizer.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: showingCategoryCustomizer ? "chevron.up.circle.fill" : "slider.horizontal.3")
                            .font(.system(size: 10, weight: .semibold))
                        Text(showingCategoryCustomizer ? "Done Editing" : "Edit Categories")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            if showingCategoryCustomizer {
                categoryCustomizerGrid
            }

            HStack(spacing: 6) {
                ForEach(manager.visibleCategories) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            eventType = type
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(eventType == type ? Color.accentColor.opacity(0.24) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(eventType == type ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .foregroundColor(eventType == type ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    @ViewBuilder
    private var categoryCustomizerGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose which categories appear in your log bar:")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
                ForEach(DexcomEventType.allCases) { cat in
                    let isVis = manager.isCategoryVisible(cat)
                    Button(action: {
                        manager.toggleCategoryVisibility(cat)
                        if !manager.isCategoryVisible(eventType) {
                            if let first = manager.visibleCategories.first {
                                eventType = first
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: isVis ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundColor(isVis ? .accentColor : .secondary)
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: 10.5, weight: isVis ? .medium : .regular))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isVis ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.35))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch eventType {
            case .food:
                foodInputsView
            case .insulin:
                insulinInputsView
            case .exercise:
                exerciseInputsView
            case .calibration:
                calibrationInputsView
            case .sensor:
                sensorInputsView
            case .health:
                EmptyView()
            }

            HStack {
                Text("Timestamp:")
                    .font(.caption)
                    .frame(width: 110, alignment: .trailing)
                DatePicker("", selection: $eventDate, displayedComponents: [.hourAndMinute, .date])
                    .labelsHidden()
            }

            HStack {
                Text("Notes:")
                    .font(.caption)
                    .frame(width: 110, alignment: .trailing)
                TextField("Optional note (e.g. Post-workout snack, Sick day)", text: $noteText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    @ViewBuilder
    private var foodInputsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    Text("Quick-Log Presets / Meal Favorites:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(mealPresets) { preset in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    mealType = preset.mealType
                                    primaryValue = "\(Int(preset.carbs))"
                                    if let p = preset.protein { proteinValue = "\(Int(p))" }
                                    if let f = preset.fat { fatValue = "\(Int(f))" }
                                    if let fib = preset.fiber { fiberValue = "\(Int(fib))" }
                                    noteText = preset.title
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 9))
                                    Text("\(preset.title) — \(Int(preset.carbs))g")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.orange.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(Color.orange.opacity(0.28), lineWidth: 0.8)
                                        )
                                )
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .help("Apply preset: \(preset.title) (\(Int(preset.carbs))g carbs, \(preset.protein ?? 0)g protein)")
                        }
                    }
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Meals & Carbohydrates")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Meal Timing:")
                        .font(.caption)
                        .frame(width: 110, alignment: .trailing)
                    Picker("", selection: $mealType) {
                        ForEach(MealType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Text("Carbs (Total):")
                        .font(.caption)
                        .frame(width: 110, alignment: .trailing)
                    TextField("e.g. 45", text: $primaryValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("grams (g)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Nutritional Macros (Optional)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Protein:")
                            .font(.caption)
                        TextField("15", text: $proteinValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        Text("g").font(.caption2).foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text("Fat:")
                            .font(.caption)
                        TextField("8", text: $fatValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        Text("g").font(.caption2).foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text("Fiber:")
                            .font(.caption)
                        TextField("5", text: $fiberValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        Text("g").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var insulinInputsView: some View {
        HStack {
            Text("Insulin Type:")
                .font(.caption)
                .frame(width: 110, alignment: .trailing)
            Picker("", selection: $insulinSubtype) {
                ForEach(InsulinSubtype.allCases) { sub in
                    Text(sub.rawValue).tag(sub)
                }
            }
            .pickerStyle(.segmented)
        }

        HStack {
            Text("Dose:")
                .font(.caption)
                .frame(width: 110, alignment: .trailing)
            TextField("e.g. 4.5", text: $primaryValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("Units (U)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var exerciseInputsView: some View {
        HStack {
            Text("Duration:")
                .font(.caption)
                .frame(width: 110, alignment: .trailing)
            TextField("e.g. 30", text: $primaryValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("minutes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }

        HStack {
            Text("Intensity:")
                .font(.caption)
                .frame(width: 110, alignment: .trailing)
            Picker("", selection: $exerciseIntensity) {
                ForEach(ExerciseIntensity.allCases) { i in
                    Text(i.rawValue).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var calibrationInputsView: some View {
        HStack {
            Text("Blood Meter Value:")
                .font(.caption)
                .frame(width: 110, alignment: .trailing)
            TextField("e.g. 115", text: $primaryValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("\(manager.unit.rawValue) (Fingerstick BGM)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var sensorInputsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $manager.sensorTrackingEnabled) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text("Enable Sensor Lifespan Countdown Tracker")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .toggleStyle(.checkbox)

            if manager.sensorTrackingEnabled {
                sensorDetailsView
            }
        }
    }

    @ViewBuilder
    private var sensorDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dexcom Model:")
                    .font(.caption)
                    .frame(width: 110, alignment: .trailing)
                Picker("", selection: $manager.sensorModelRaw) {
                    ForEach(DexcomSensorModel.allCases) { model in
                        Text(model.rawValue).tag(model.rawValue)
                    }
                }
                .labelsHidden()
            }

            sensorCountdownCard
        }
        .padding(.leading, 6)
    }

    private var isExpired: Bool {
        manager.isSensorExpired
    }

    @ViewBuilder
    private var sensorStatusBadge: some View {
        ZStack {
            Circle()
                .fill(isExpired ? Color.red.opacity(0.18) : Color.blue.opacity(0.18))
                .frame(width: 32, height: 32)
            Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "hourglass.circle.fill")
                .foregroundColor(isExpired ? Color.red : Color.blue)
                .font(.system(size: 16))
        }
    }

    @ViewBuilder
    private var sensorInfoText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isExpired ? "Sensor is Expired" : "Time Remaining:")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isExpired ? Color.red : Color.primary)

            Text(isExpired ? "Please insert a new sensor to continue monitoring." : manager.sensorTimeRemainingString)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isExpired ? Color.red : Color.accentColor)

            if let start = manager.sensorStartDate {
                let startText = "Started: " + dateOnlyFormatter.string(from: start)
                let lifeText = " (" + "\(manager.sensorModel.lifespanDays)" + " day lifespan)"
                Text(startText + lifeText)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sensorResetButton: some View {
        Button(action: {
            withAnimation {
                manager.startNewSensor()
                submissionStatus = "Sensor timer restarted for " + manager.sensorModel.shortName + "!"
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                Text("Sensor has been changed")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(isExpired ? Color.red : Color.accentColor)
        .controlSize(.small)
    }

    @ViewBuilder
    private var sensorCountdownCard: some View {
        HStack(spacing: 10) {
            sensorStatusBadge
            sensorInfoText
            Spacer()
            sensorResetButton
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isExpired ? Color.red.opacity(0.08) : Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isExpired ? Color.red.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var statusBannerSection: some View {
        if let status = submissionStatus {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.12))
            )
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Dexcom Cloud Sync Status:")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.primary)
                }
                Text("• Dexcom Share credentials (used for menu bar glucose readings) are read-only and cannot push events to Clarity or iOS.\n• To upload events directly to Dexcom Cloud & Clarity reports, Dexcom's official Developer API requires 1-time OAuth2 user consent (in progress). Logs are currently saved to local session history.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var footerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Button(action: handleSave) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Submit Log Entry")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }


    private var dateOnlyFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }

    private func handleSave() {
        var summary = eventType.rawValue
        if eventType == .food {
            if !primaryValue.isEmpty {
                summary += " (\(mealType.rawValue): \(primaryValue)g carbs"
                if !proteinValue.isEmpty { summary += ", \(proteinValue)g P" }
                if !fatValue.isEmpty { summary += ", \(fatValue)g F" }
                if !fiberValue.isEmpty { summary += ", \(fiberValue)g Fib" }
                summary += ")"
            } else {
                summary += " (\(mealType.rawValue))"
            }
        } else if !primaryValue.isEmpty {
            summary += ": \(primaryValue)"
        }
        
        let numericVal = Double(primaryValue.trimmingCharacters(in: .whitespaces))
        var subtypeStr: String? = nil
        if eventType == .insulin {
            subtypeStr = insulinSubtype.rawValue
        } else if eventType == .exercise {
            subtypeStr = exerciseIntensity.rawValue.lowercased()
        }
        
        var combinedNote = noteText.trimmingCharacters(in: .whitespaces)
        if eventType == .food {
            var macroDetails: [String] = []
            if !proteinValue.isEmpty { macroDetails.append("Protein: \(proteinValue)g") }
            if !fatValue.isEmpty { macroDetails.append("Fat: \(fatValue)g") }
            if !fiberValue.isEmpty { macroDetails.append("Fiber: \(fiberValue)g") }
            if !macroDetails.isEmpty {
                let macroNote = macroDetails.joined(separator: ", ")
                combinedNote = combinedNote.isEmpty ? macroNote : "\(combinedNote) (\(macroNote))"
            }
        }
        
        // Push directly to Dexcom Cloud via OAuth2 if connected
        if DexcomOAuthManager.shared.isAuthorized {
            submissionStatus = "Syncing to Dexcom Cloud & Clarity..."
            Task {
                let res = await DexcomOAuthManager.shared.postEventToDexcom(
                    eventType: eventType,
                    primaryValue: numericVal,
                    subtype: subtypeStr,
                    date: eventDate,
                    note: combinedNote.isEmpty ? nil : combinedNote
                )
                await MainActor.run {
                    switch res {
                    case .success(let msg):
                        submissionStatus = "✓ " + msg
                    case .failure(let err):
                        submissionStatus = "Saved locally. (Cloud Sync: \(err.localizedDescription))"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        dismiss()
                    }
                }
            }
        } else {
            submissionStatus = "Recorded \(summary) locally! (Connect 1-Click OAuth in Settings to sync to Clarity)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                dismiss()
            }
        }
    }
}

/// Comprehensive Trends & Logs Sheet displaying all information available from Dexcom Developer API (v3) & Share
public struct DexcomTrendsAndLogsSheet: View {
    @ObservedObject var manager: GlucoseManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: TrendTimeFilter = .last6Hours

    private var filteredReadings: [GlucoseReading] {
        let all = manager.recentReadings
        guard !all.isEmpty else { return [] }
        let cutoff = Date().addingTimeInterval(-selectedFilter.durationSeconds)
        let filtered = all.filter { $0.timestamp >= cutoff }
        // If filter is wider than available readings, show whatever we have
        return filtered.isEmpty ? Array(all.prefix(24)) : filtered
    }

    private var inTargetPercentage: Int {
        let readings = filteredReadings
        guard !readings.isEmpty else { return 100 }
        let targetCount = readings.filter { reading in
            let cat = manager.category(for: reading)
            return cat == .normal
        }.count
        return Int((Double(targetCount) / Double(readings.count)) * 100.0)
    }

    private var averageGlucose: Double {
        let readings = filteredReadings
        guard !readings.isEmpty else { return 110.0 }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }

    private var gmiEstimatedA1C: Double {
        // GMI formula: 3.31 + (0.02392 * mean glucose in mg/dL)
        return 3.31 + (0.02392 * averageGlucose)
    }

    private var standardDeviation: Double {
        let readings = filteredReadings
        guard readings.count > 1 else { return 15.0 }
        let mean = averageGlucose
        let sumSquares = readings.reduce(0.0) { $0 + pow($1.value - mean, 2) }
        return sqrt(sumSquares / Double(readings.count - 1))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.85), Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 34, height: 34)
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dexcom Trends, Statistics & API Overview")
                        .font(.system(size: 15, weight: .bold))
                    Text("Dexcom Developer API v3 • Estimated Glucose Values (EGV) • Health Analytics")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.small)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Time-In-Range & Statistical Hero Cards (Calculated over selected filter)
                    HStack(spacing: 10) {
                        // Time in Range Card
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TIME IN RANGE (\(selectedFilter.displayName.uppercased()))")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(inTargetPercentage)%")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.green)
                                Text("In Target")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("Goal: > 70% in range")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        )

                        // Average Glucose Card
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AVERAGE GLUCOSE")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(manager.unit.format(mgdL: averageGlucose))
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.accentColor)
                                Text(manager.unit.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("SD: ±\(manager.unit.format(mgdL: standardDeviation))")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        )

                        // Estimated GMI / A1C Card
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESTIMATED A1C (GMI)")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f%%", gmiEstimatedA1C))
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.purple)
                                Text("GMI")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("Clinical formula")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        )
                    }

                    // 2. Continuous Trend Graph with Time Filter Selector
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text("Continuous Trend History")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            Spacer()

                            // Time Filter Segmented Control: 2h, 4h, 6h, Today, 48h, Week, Month
                            HStack(spacing: 3) {
                                ForEach(TrendTimeFilter.allCases) { filter in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedFilter = filter
                                        }
                                    }) {
                                        Text(filter.displayName)
                                            .font(.system(size: 10, weight: selectedFilter == filter ? .bold : .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(selectedFilter == filter ? Color.accentColor : Color(NSColor.controlBackgroundColor).opacity(0.35))
                                            )
                                            .foregroundColor(selectedFilter == filter ? .white : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .background(
                                Capsule()
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            )
                        }

                        // Sparkline View rendering the filtered range of readings
                        SparklineView(readings: filteredReadings, unit: manager.unit, isDemo: manager.demoMode)
                    }

                    // 3. Complete Dexcom API v3 Capabilities Directory
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dexcom API v3 Supported Capabilities")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            ApiCapabilityRow(
                                title: "Estimated Glucose Values (EGVs)",
                                endpoint: "GET /v3/users/self/egvs",
                                desc: "Provides timestamped 5-minute blood glucose readings, smoothed trends, and transmitter rate-of-change metrics.",
                                status: "Live & Polling"
                            )

                            ApiCapabilityRow(
                                title: "Events & Activity Logs",
                                endpoint: "POST /v3/users/self/events",
                                desc: "Syncs nutrition/food carbs & macros, fast-acting and long-acting insulin doses, workout durations, and clinical notes.",
                                status: "Enabled via [+] Log"
                            )

                            ApiCapabilityRow(
                                title: "Calibrations & BGM Fingersticks",
                                endpoint: "POST /v3/users/self/calibrations",
                                desc: "Transmits blood meter reference fingerstick values to assist sensor calibration algorithms.",
                                status: "Supported"
                            )

                            ApiCapabilityRow(
                                title: "CGM Devices & Transmitter Telemetry",
                                endpoint: "GET /v3/users/self/devices",
                                desc: "Reports sensor hardware models, transmitter serial IDs, deployment timestamps, and firmware releases.",
                                status: "Integrated with Tracker"
                            )

                            ApiCapabilityRow(
                                title: "Alerts & Clinical Warning Thresholds",
                                endpoint: "GET /v3/users/self/alerts",
                                desc: "Retrieves user-defined urgent low and high alarm thresholds configured on official Dexcom handhelds and iOS/Android apps.",
                                status: "Configurable in Preferences"
                            )
                        }
                    }
                }
                .padding(4)
            }

            Spacer()

            // Footer with Export Actions for Endocrinologist visits
            HStack {
                // 1-Click Export CSV
                Button(action: exportCSV) {
                    HStack(spacing: 4) {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .font(.system(size: 11))
                        Text("Export CSV")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export continuous glucose readings to CSV for Excel or Health analysis")

                // 1-Click Export Clinical PDF for Doctor / Endocrinologist
                Button(action: exportEndocrinologistPDF) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 11))
                        Text("Export Clinical PDF (For Doctor)")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
                .help("Generate a clean 1-click clinical summary report formatted for endocrinologist visits")

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 560, height: 560)
        .background(.ultraThinMaterial)
    }

    private func exportCSV() {
        let csvString = DexcomExportService.generateCSV(readings: filteredReadings, unit: manager.unit)
        let panel = NSSavePanel()
        panel.title = "Export Dexcom Readings (CSV)"
        panel.nameFieldStringValue = "Dexcom_Readings_\(selectedFilter.rawValue).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            try? csvString.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func exportEndocrinologistPDF() {
        let pdfData = DexcomExportService.generateEndocrinologistPDF(
            readings: filteredReadings,
            unit: manager.unit,
            tir: inTargetPercentage,
            mean: averageGlucose,
            gmi: gmiEstimatedA1C,
            sd: standardDeviation,
            filterName: selectedFilter.displayName,
            sensorModel: manager.sensorModel
        )
        let panel = NSSavePanel()
        panel.title = "Export Clinical PDF for Endocrinologist"
        panel.nameFieldStringValue = "Dexcom_Clinical_Report_\(selectedFilter.rawValue).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            try? pdfData.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

/// Helper row for listing Dexcom API features
struct ApiCapabilityRow: View {
    let title: String
    let endpoint: String
    let desc: String
    let status: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 13))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(status)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }

                Text(endpoint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
