import Foundation
import XCTest
import ToDocCoreErrors
@testable import ToDocDomain

final class UserTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    private func user(name: String = "김하늘") throws -> User {
        // User는 프로필만 보관합니다. 날짜를 고정해 실행 시점에 따라 결과가 변하지 않게 합니다.
        try User(id: UUID(), name: name, birthday: date(2000, 10, 11), sex: .female,
                 now: date(2026, 10, 11), calendar: calendar)
    }

    func testNameTrimsEdgesAndAcceptsTenUnicodeCharacters() throws {
        XCTAssertEqual(try user(name: "  Jean-Luc  ").name, "Jean-Luc")
        XCTAssertEqual(try user(name: String(repeating: "가", count: 10)).name.count, 10)
    }
    func testNameValidationAlsoProtectsUpdates() throws {
        var value = try user()
        for (name, error) in [("  ", NameValidationError.empty),
                              (String(repeating: "가", count: 11), .tooLong), ("김\n하늘", .invalidCharacter)] {
            XCTAssertThrowsError(try user(name: name)) { XCTAssertEqual($0 as? NameValidationError, error) }
            XCTAssertThrowsError(try value.updateName(name)) { XCTAssertEqual($0 as? NameValidationError, error) }
            XCTAssertEqual(value.name, "김하늘")
        }
        let id = value.id
        try value.updateName(" 김가을 ")
        value.updateSex(.male)
        XCTAssertEqual(value.name, "김가을")
        XCTAssertEqual(value.sex, .male)
        XCTAssertEqual(value.id, id)
    }
    func testPublicInitializerKeepsProfileValidation() throws {
        // 최신 develop의 User는 이메일을 받지 않습니다. 인증 정보와 프로필을 분리한 팀 모델을 그대로 검사합니다.
        let birthday = date(2000, 10, 11)
        let id = UUID()
        let profile = try User(id: id, name: " 김하늘 ", birthday: birthday, sex: .female)
        XCTAssertEqual(profile.name, "김하늘")
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.birthday, birthday)
        XCTAssertEqual(profile.sex, .female)
        XCTAssertThrowsError(try User(id: id, name: " ", birthday: birthday, sex: .female)) {
            XCTAssertEqual($0 as? NameValidationError, .empty)
        }
        XCTAssertThrowsError(try User(id: id, name: "김하늘", birthday: .distantFuture, sex: .female)) {
            XCTAssertEqual($0 as? DateValidationError, .futureDate)
        }
    }
    func testBirthdayUsesDayBoundaryAndRejectedUpdateIsAtomic() throws {
        let today = date(2026, 10, 11)
        var value = try user()
        let original = value.birthday
        XCTAssertThrowsError(try value.updateBirthday(date(2026, 10, 12), now: today, calendar: calendar)) {
            XCTAssertEqual($0 as? DateValidationError, .futureDate)
        }
        XCTAssertEqual(value.birthday, original)
        XCTAssertThrowsError(try User(id: UUID(), name: "김하늘",
            birthday: date(2026, 10, 12), sex: .female, now: today, calendar: calendar)) {
            XCTAssertEqual($0 as? DateValidationError, .futureDate)
        }
        let lateToday = date(2026, 10, 11, hour: 23)
        try value.updateBirthday(lateToday, now: today, calendar: calendar)
        XCTAssertEqual(value.birthday, lateToday)
        try value.updateBirthday(date(2000, 1, 1))
        XCTAssertEqual(value.birthday, date(2000, 1, 1))
    }
    func testAgeBeforeOnAndAfterBirthday() throws {
        let value = try user()
        XCTAssertEqual(value.age(on: date(2026, 10, 10), calendar: calendar), 25)
        XCTAssertEqual(value.age(on: date(2026, 10, 11), calendar: calendar), 26)
        XCTAssertEqual(value.age(on: date(2026, 10, 12), calendar: calendar), 26)
        XCTAssertEqual(value.age(on: date(2027, 1, 1), calendar: calendar), 26)
    }
    func testLeapBirthdayInNonLeapYear() throws {
        let value = try User(id: UUID(), name: "김하늘", birthday: date(2000, 2, 29),
                             sex: .female, now: date(2026, 10, 11), calendar: calendar)
        XCTAssertEqual(value.age(on: date(2025, 2, 28), calendar: calendar), 24)
        XCTAssertEqual(value.age(on: date(2025, 3, 1), calendar: calendar), 25)
    }
    func testCalendarTimezoneControlsFutureDayValidation() throws {
        var seoul = calendar
        seoul.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let now = date(2026, 10, 11, hour: 16)
        let birthday = date(2026, 10, 12, hour: 1)
        XCTAssertNoThrow(try User(id: UUID(), name: "김하늘", birthday: birthday,
                                 sex: .male, now: now, calendar: seoul))
        XCTAssertThrowsError(try User(id: UUID(), name: "김하늘", birthday: birthday,
                                     sex: .male, now: now, calendar: calendar))
    }
}
