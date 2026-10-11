import Foundation
import SwiftUI

/// Account login type: Personal Sharer (Wearer)
public enum DexcomAccountType: String, CaseIterable, Identifiable, Codable {
    case sharer = "Primary Sharer (Wearer)"

    public var id: String { rawValue }

    public var description: String {
        "Primary account of the person wearing the Dexcom CGM (with Dexcom Share enabled)."
    }
}

/// Dexcom sensor models with standard lifespan days
public enum DexcomSensorModel: String, CaseIterable, Identifiable, Codable {
    case g7 = "Dexcom G7 (10 Days)"
    case g6 = "Dexcom G6 (10 Days)"
    case one = "Dexcom ONE (10 Days)"
    case onePlus = "Dexcom ONE+ (10 Days)"
    case stelo = "Dexcom Stelo (15 Days)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .g7: return "G7"
        case .g6: return "G6"
        case .one: return "ONE"
        case .onePlus: return "ONE+"
        case .stelo: return "Stelo"
        }
    }

    public var lifespanDays: Int {
        switch self {
        case .g7, .g6, .one, .onePlus:
            return 10
        case .stelo:
            return 15
        }
    }

    public var lifespanSeconds: TimeInterval {
        TimeInterval(lifespanDays * 24 * 3600)
    }
}

/// Time interval filters for the Trends & Logs graph
public enum TrendTimeFilter: String, CaseIterable, Identifiable {
    case last2Hours = "2h"
    case last4Hours = "4h"
    case last6Hours = "6h"
    case today = "Today"
    case last48Hours = "48h"
    case thisWeek = "Week"
    case monthly = "Month"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .last2Hours: return "Last 2h"
        case .last4Hours: return "Last 4h"
        case .last6Hours: return "Last 6h"
        case .today: return "Today"
        case .last48Hours: return "48h"
        case .thisWeek: return "This Week"
        case .monthly: return "Monthly"
        }
    }

    public var durationSeconds: TimeInterval {
        switch self {
        case .last2Hours: return 2 * 3600
        case .last4Hours: return 4 * 3600
        case .last6Hours: return 6 * 3600
        case .today: return 24 * 3600
        case .last48Hours: return 48 * 3600
        case .thisWeek: return 7 * 24 * 3600
        case .monthly: return 30 * 24 * 3600
        }
    }
}

/// Dexcom Event types for logging
public enum DexcomEventType: String, CaseIterable, Identifiable, Codable {
    case food = "Food"
    case insulin = "Insulin"
    case exercise = "Exercise"
    case calibration = "BGM Cal"
    case sensor = "Sensor"
    case health = "Health / Note"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .insulin: return "cross.vial.fill"
        case .exercise: return "figure.run"
        case .calibration: return "drop.triangle.fill"
        case .sensor: return "sensor.tag.radiowaves.forward.fill"
        case .health: return "heart.text.square.fill"
        }
    }
}

/// Predefined color options for status item droplet (Low and High) - without green
public enum AppColorOption: String, CaseIterable, Identifiable, Codable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case cyan = "Cyan"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .cyan: return .cyan
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .cyan: return .systemTeal
        }
    }
}

/// Color option for Normal in-range readings: Green or White (default template label)
public enum NormalColorOption: String, CaseIterable, Identifiable, Codable {
    case green = "Green"
    case white = "White"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .green: return .green
        case .white: return .primary
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .green: return .systemGreen
        case .white: return .white
        }
    }
}

/// 10 audio sound effects for urgent low and high alerts
public enum AlertSoundOption: String, CaseIterable, Identifiable, Codable {
    case sosumi = "Sosumi"
    case hero = "Hero"
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case ping = "Ping"
    case submarine = "Submarine"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sosumi: return "Sosumi (Classic Alert)"
        case .hero: return "Hero (Fanfare)"
        case .basso: return "Basso (Deep Warning)"
        case .blow: return "Blow (Subtle Whoosh)"
        case .bottle: return "Bottle (Pop Sound)"
        case .frog: return "Frog (Ribbit Chime)"
        case .funk: return "Funk (Synth Chord)"
        case .glass: return "Glass (Glass Bell)"
        case .ping: return "Ping (High Ping)"
        case .submarine: return "Submarine (Sonar Ping)"
        }
    }

    public func play() {
        if let sound = NSSound(named: rawValue) ?? NSSound(named: "Ping") {
            sound.play()
        }
    }
}

/// Trend arrow representation returned by Dexcom Share
public enum GlucoseTrend: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case doubleUp = "DoubleUp"
    case singleUp = "SingleUp"
    case fortyFiveUp = "FortyFiveUp"
    case flat = "Flat"
    case fortyFiveDown = "FortyFiveDown"
    case singleDown = "SingleDown"
    case doubleDown = "DoubleDown"
    case notComputable = "NotComputable"
    case rateOutOfRange = "RateOutOfRange"

    public var symbol: String {
        switch self {
        case .doubleUp: return "↑↑"
        case .singleUp: return "↑"
        case .fortyFiveUp: return "↗"
        case .flat: return "→"
        case .fortyFiveDown: return "↘"
        case .singleDown: return "↓"
        case .doubleDown: return "↓↓"
        case .none, .notComputable, .rateOutOfRange: return "–"
        }
    }

    public var description: String {
        switch self {
        case .doubleUp: return "Rising rapidly (>3 mg/dL/min)"
        case .singleUp: return "Rising (2-3 mg/dL/min)"
        case .fortyFiveUp: return "Rising slowly (1-2 mg/dL/min)"
        case .flat: return "Steady"
        case .fortyFiveDown: return "Falling slowly (1-2 mg/dL/min)"
        case .singleDown: return "Falling (2-3 mg/dL/min)"
        case .doubleDown: return "Falling rapidly (>3 mg/dL/min)"
        case .none: return "No trend data"
        case .notComputable: return "Trend not computable"
        case .rateOutOfRange: return "Rate out of range"
        }
    }
}

/// Blood glucose display units
public enum GlucoseUnit: String, CaseIterable, Identifiable, Codable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"

    public var id: String { rawValue }

    public func format(mgdL: Double) -> String {
        switch self {
        case .mgdL:
            return String(format: "%.0f", mgdL)
        case .mmolL:
            // 1 mmol/L = 18.0182 mg/dL
            return String(format: "%.1f", mgdL / 18.0182)
        }
    }
}

/// Health status category based on standard target ranges
public enum GlucoseCategory {
    case veryLow      // < 55 mg/dL
    case low          // 55 - 69 mg/dL
    case normal       // 70 - 180 mg/dL
    case high         // 181 - 250 mg/dL
    case veryHigh     // > 250 mg/dL

    public static func from(
        mgdL: Double,
        lowThreshold: Double = 70.0,
        highThreshold: Double = 180.0,
        urgentLowThreshold: Double = 55.0,
        urgentHighThreshold: Double = 250.0
    ) -> GlucoseCategory {
        if mgdL <= urgentLowThreshold {
            return .veryLow
        } else if mgdL < lowThreshold {
            return .low
        } else if mgdL <= highThreshold {
            return .normal
        } else if mgdL < urgentHighThreshold {
            return .high
        } else {
            return .veryHigh
        }
    }

    public var title: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .normal: return "In Target Range"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    public var color: Color {
        switch self {
        case .veryLow: return Color.red
        case .low: return Color.red.opacity(0.85)
        case .normal: return Color.green
        case .high: return Color.orange
        case .veryHigh: return Color.red
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .veryLow: return NSColor.systemRed
        case .low: return NSColor.systemRed
        case .normal: return NSColor.systemGreen
        case .high: return NSColor.systemOrange
        case .veryHigh: return NSColor.systemRed
        }
    }
}

/// Normalized internal Glucose Reading model
public struct GlucoseReading: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let value: Double // stored in mg/dL
    public let trend: GlucoseTrend
    public let timestamp: Date

    public init(id: UUID = UUID(), value: Double, trend: GlucoseTrend, timestamp: Date) {
        self.id = id
        self.value = value
        self.trend = trend
        self.timestamp = timestamp
    }

    public func category(
        lowThreshold: Double = 70.0,
        highThreshold: Double = 180.0,
        urgentLowThreshold: Double = 55.0,
        urgentHighThreshold: Double = 250.0
    ) -> GlucoseCategory {
        GlucoseCategory.from(
            mgdL: value,
            lowThreshold: lowThreshold,
            highThreshold: highThreshold,
            urgentLowThreshold: urgentLowThreshold,
            urgentHighThreshold: urgentHighThreshold
        )
    }

    public var category: GlucoseCategory {
        GlucoseCategory.from(mgdL: value)
    }

    public var isStale: Bool {
        // Readings older than 15 minutes are considered stale
        Date().timeIntervalSince(timestamp) > 15 * 60
    }

    public var minutesAgo: Int {
        max(0, Int(Date().timeIntervalSince(timestamp) / 60))
    }

    public func formattedValue(unit: GlucoseUnit) -> String {
        unit.format(mgdL: value)
    }
}
