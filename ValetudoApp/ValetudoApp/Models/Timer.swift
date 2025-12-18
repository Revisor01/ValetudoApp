import Foundation

struct ValetudoTimer: Codable, Identifiable {
    let id: String
    var enabled: Bool
    var label: String?
    var dow: [Int]  // Day of week: 0=Sunday, 1=Monday, ... 6=Saturday
    var hour: Int
    var minute: Int
    var action: TimerAction
    var pre_actions: [PreAction]?
}

struct TimerAction: Codable {
    var type: String  // "full_cleanup" or "segment_cleanup"
    var params: TimerParams?
}

struct TimerParams: Codable {
    var segment_ids: [String]?
    var iterations: Int?
    var custom_order: Bool?
}

struct PreAction: Codable {
    var type: String
    var params: PreActionParams?
}

struct PreActionParams: Codable {
    var value: String?
}

// MARK: - Display Helpers
extension ValetudoTimer {
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var localTimeString: String {
        let (localHour, localMinute) = Self.utcToLocal(hour: hour, minute: minute)
        return String(format: "%02d:%02d", localHour, localMinute)
    }

    var localHour: Int {
        Self.utcToLocal(hour: hour, minute: minute).hour
    }

    var localMinute: Int {
        Self.utcToLocal(hour: hour, minute: minute).minute
    }

    /// Converts UTC time to local time
    static func utcToLocal(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        let utcOffset = TimeZone.current.secondsFromGMT()
        let totalMinutes = hour * 60 + minute + (utcOffset / 60)

        var adjustedMinutes = totalMinutes % (24 * 60)
        if adjustedMinutes < 0 {
            adjustedMinutes += 24 * 60
        }

        return (hour: adjustedMinutes / 60, minute: adjustedMinutes % 60)
    }

    /// Converts local time to UTC
    static func localToUTC(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        let utcOffset = TimeZone.current.secondsFromGMT()
        let totalMinutes = hour * 60 + minute - (utcOffset / 60)

        var adjustedMinutes = totalMinutes % (24 * 60)
        if adjustedMinutes < 0 {
            adjustedMinutes += 24 * 60
        }

        return (hour: adjustedMinutes / 60, minute: adjustedMinutes % 60)
    }

    var dowString: String {
        let shortDays = [
            String(localized: "day.sun"),
            String(localized: "day.mon"),
            String(localized: "day.tue"),
            String(localized: "day.wed"),
            String(localized: "day.thu"),
            String(localized: "day.fri"),
            String(localized: "day.sat")
        ]

        if dow.count == 7 {
            return String(localized: "timer.daily")
        }

        if dow == [1, 2, 3, 4, 5] {
            return String(localized: "timer.weekdays")
        }

        if dow == [0, 6] {
            return String(localized: "timer.weekends")
        }

        return dow.sorted().map { shortDays[$0] }.joined(separator: ", ")
    }

    var actionTypeString: String {
        switch action.type {
        case "full_cleanup":
            return String(localized: "timer.full_cleanup")
        case "segment_cleanup":
            return String(localized: "timer.segment_cleanup")
        default:
            return action.type
        }
    }
}

// MARK: - Create Request
struct CreateTimerRequest: Codable {
    var enabled: Bool
    var label: String?
    var dow: [Int]
    var hour: Int
    var minute: Int
    var action: TimerAction
}
