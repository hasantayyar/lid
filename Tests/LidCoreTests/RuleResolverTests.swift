import XCTest
@testable import LidCore

final class RuleResolverTests: XCTestCase {
    private let resolver = RuleResolver()
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func testGlobalDisableWins() throws {
        var settings = AppSettings.default
        settings.automationEnabled = false
        let resolution = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 3, 12, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertEqual(resolution, .inactiveGlobal)
    }

    func testSnoozeWinsOverSchedule() throws {
        var settings = AppSettings.default
        settings.schedules = [ScheduleWindow(weekdays: [4], startMinutes: 0, endMinutes: 24 * 60 - 1)]
        let snooze = SnoozeState.starting(.minutes5, now: date(2024, 1, 3, 12, 0))
        let resolution = resolver.resolve(
            settings: settings,
            snooze: snooze,
            now: date(2024, 1, 3, 12, 1),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertEqual(resolution, .snoozed)
    }

    func testApplicationExclusion() throws {
        var settings = AppSettings.default
        settings.applicationExclusions = ["com.apple.FaceTime"]
        let resolution = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 3, 12, 0),
            calendar: calendar,
            foregroundBundleID: "com.apple.FaceTime"
        )
        XCTAssertEqual(resolution, .excludedApplication(bundleID: "com.apple.FaceTime"))
    }

    func testSameDaySchedule() {
        var settings = AppSettings.default
        settings.schedules = [ScheduleWindow(weekdays: [4], startMinutes: 9 * 60, endMinutes: 17 * 60)]
        let inside = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 3, 10, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertTrue(inside.allowsActions)
        let outside = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 3, 20, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertEqual(outside, .outsideSchedule)
    }

    func testOvernightSchedule() {
        var settings = AppSettings.default
        settings.schedules = [ScheduleWindow(weekdays: [6], startMinutes: 22 * 60, endMinutes: 6 * 60)]
        let fridayNight = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 5, 23, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertTrue(fridayNight.allowsActions)
        let saturdayMorning = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 6, 5, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertTrue(saturdayMorning.allowsActions)
        let saturdayAfternoon = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date(2024, 1, 6, 15, 0),
            calendar: calendar,
            foregroundBundleID: nil
        )
        XCTAssertEqual(saturdayAfternoon, .outsideSchedule)
    }

    func testTimezoneChangeUsesInjectedCalendar() {
        var nyc = Calendar(identifier: .gregorian)
        nyc.timeZone = TimeZone(identifier: "America/New_York")!
        var settings = AppSettings.default
        settings.schedules = [ScheduleWindow(weekdays: [2], startMinutes: 9 * 60, endMinutes: 10 * 60)]
        let date = Date(timeIntervalSince1970: 1_704_210_000)
        let resolution = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: date,
            calendar: nyc,
            foregroundBundleID: nil
        )
        XCTAssertTrue([RuleResolution.active(reason: "Inside a scheduled window"), .outsideSchedule].contains(resolution))
    }

    func testDaylightSavingSpringForwardDoesNotCrash() {
        var nyc = Calendar(identifier: .gregorian)
        nyc.timeZone = TimeZone(identifier: "America/New_York")!
        var settings = AppSettings.default
        settings.schedules = [ScheduleWindow(weekdays: Set(1...7), startMinutes: 2 * 60, endMinutes: 4 * 60)]
        let spring = Date(timeIntervalSince1970: 1_709_881_200)
        let resolution = resolver.resolve(
            settings: settings,
            snooze: .inactive,
            now: spring,
            calendar: nyc,
            foregroundBundleID: nil
        )
        XCTAssertNotNil(resolution)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }
}
