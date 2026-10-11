import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

nonisolated enum DomainDateRules {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func validateBirthday(_ birthday: Date, now: Date, calendar: Calendar) throws {
        guard calendar.compare(birthday, to: now, toGranularity: .day) != .orderedDescending else {
            throw DateValidationError.futureDate
        }
    }

    static func age(birthday: Date, now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.year], from: calendar.startOfDay(for: birthday),
                                to: calendar.startOfDay(for: now)).year ?? 0
    }
}
