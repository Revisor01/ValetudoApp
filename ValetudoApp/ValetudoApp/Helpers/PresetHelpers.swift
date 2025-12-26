import SwiftUI

// MARK: - Preset Display Helpers
enum PresetHelpers {
    static func displayName(for preset: String) -> String {
        switch preset.lowercased() {
        case "off": return String(localized: "preset.off")
        case "min": return String(localized: "preset.min")
        case "low": return String(localized: "preset.low")
        case "medium": return String(localized: "preset.medium")
        case "high": return String(localized: "preset.high")
        case "max": return String(localized: "preset.max")
        case "turbo": return String(localized: "preset.turbo")
        default: return preset.capitalized
        }
    }

    static func color(for preset: String) -> Color {
        switch preset.lowercased() {
        case "off": return .gray
        case "min": return .green
        case "low": return .mint
        case "medium": return .blue
        case "high": return .orange
        case "max", "turbo": return .red
        default: return .blue
        }
    }
}

// MARK: - Operation Mode Display Helpers
enum OperationModeHelpers {
    static func displayName(for mode: String) -> String {
        switch mode.lowercased() {
        case "vacuum": return String(localized: "mode.vacuum")
        case "mop": return String(localized: "mode.mop")
        case "vacuum_and_mop": return String(localized: "mode.vacuum_and_mop")
        case "vacuum_then_mop": return String(localized: "mode.vacuum_then_mop")
        default: return mode.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func icon(for mode: String) -> String {
        switch mode.lowercased() {
        case "vacuum": return "tornado"
        case "mop": return "drop.fill"
        case "vacuum_and_mop", "vacuum_then_mop": return "sparkles"
        default: return "gearshape"
        }
    }

    static func color(for mode: String) -> Color {
        switch mode.lowercased() {
        case "vacuum": return .orange
        case "mop": return .blue
        case "vacuum_and_mop", "vacuum_then_mop": return .purple
        default: return .gray
        }
    }
}

// MARK: - Fan Speed Icon Helper
enum FanSpeedHelpers {
    static func icon(for preset: String) -> String {
        switch preset.lowercased() {
        case "off": return "fan.slash"
        case "min", "low": return "fan"
        case "medium", "high": return "fan.fill"
        case "max", "turbo": return "wind"
        default: return "fan"
        }
    }
}

// MARK: - Water Usage Icon Helper
enum WaterUsageHelpers {
    static func icon(for preset: String) -> String {
        switch preset.lowercased() {
        case "off": return "drop.slash"
        case "min", "low": return "drop"
        case "medium": return "drop.fill"
        case "high", "max": return "drop.circle.fill"
        default: return "drop"
        }
    }
}
