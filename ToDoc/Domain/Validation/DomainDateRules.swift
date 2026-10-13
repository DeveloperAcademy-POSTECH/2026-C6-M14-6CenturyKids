import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

/// 화면과 모델이 같은 생일 검증·만 나이 규칙을 사용합니다.
nonisolated public enum DomainDateRules {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    public static func validateBirthday(_ birthday: Date, now: Date, calendar: Calendar) throws {
        guard calendar.compare(birthday, to: now, toGranularity: .day) != .orderedDescending else {
            throw DateValidationError.futureDate
        }
    }

    public static func age(birthday: Date, now: Date, calendar: Calendar) -> Int {
        let birth = calendar.dateComponents([.year, .month, .day], from: birthday)
        let current = calendar.dateComponents([.year, .month, .day], from: now)
        guard let birthYear = birth.year, let birthMonth = birth.month, let birthDay = birth.day,
              let currentYear = current.year, let currentMonth = current.month, let currentDay = current.day else {
            return 0
        }
        // 월·일을 비교하므로 2월 29일생은 평년의 3월 1일부터 새 나이가 됩니다.
        let birthdayPassed = (currentMonth, currentDay) >= (birthMonth, birthDay)
        return currentYear - birthYear - (birthdayPassed ? 0 : 1)
    }
}
