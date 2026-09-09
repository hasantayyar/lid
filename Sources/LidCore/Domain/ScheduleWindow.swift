import Foundation

public struct ScheduleWindow: Sendable, Hashable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var enabled: Bool
    public var weekdays: Set<Int>
    public var startMinutes: Int
    public var endMinutes: Int

    public init(
        id: UUID = UUID(),
        enabled: Bool = true,
        weekdays: Set<Int> = Set(1...7),
        startMinutes: Int = 9 * 60,
        endMinutes: Int = 18 * 60
    ) {
        self.id = id
        self.enabled = enabled
        self.weekdays = weekdays
        self.startMinutes = Self.clampMinutes(startMinutes)
        self.endMinutes = Self.clampMinutes(endMinutes)
    }

    public var crossesMidnight: Bool {
        startMinutes > endMinutes
    }

    public func contains(date: Date, calendar: Calendar) -> Bool {
        guard enabled, !weekdays.isEmpty else { return false }
        let weekday = calendar.component(.weekday, from: date)
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        if !crossesMidnight {
            return weekdays.contains(weekday) && minutes >= startMinutes && minutes < endMinutes
        }

        if minutes >= startMinutes {
            return weekdays.contains(weekday)
        }
        if minutes < endMinutes {
            let previous = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(previous)
        }
        return false
    }

    private static func clampMinutes(_ value: Int) -> Int {
        min(max(value, 0), 24 * 60 - 1)
    }
}
