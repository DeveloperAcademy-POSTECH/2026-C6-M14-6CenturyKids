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
    private func user(name: String = "김하늘", email: String = "patient@example.com") throws -> User {
        try User(id: UUID(), email: email, name: name, birthday: date(2000, 10, 11), sex: .female,
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
        XCTAssertEqual(value.email, "patient@example.com")
    }
    func testEmailRejectsMalformedAddressesAndTrimsEdges() throws {
        XCTAssertEqual(try user(email: "  p+tag@example.com\n").email, "p+tag@example.com")
        XCTAssertThrowsError(try user(email: "  ")) { XCTAssertEqual($0 as? EmailValidationError, .empty) }
        for email in ["p", "@example.com", "p@", "p a@example.com", "p@example..com", ".p@example.com", "p.@example.com"] {
            XCTAssertThrowsError(try user(email: email)) { XCTAssertEqual($0 as? EmailValidationError, .invalidFormat) }
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
        XCTAssertThrowsError(try User(id: UUID(), email: "p@example.com", name: "김하늘",
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
        let value = try User(id: UUID(), email: "p@example.com", name: "김하늘", birthday: date(2000, 2, 29),
                             sex: .female, now: date(2026, 10, 11), calendar: calendar)
        XCTAssertEqual(value.age(on: date(2025, 2, 28), calendar: calendar), 24)
        XCTAssertEqual(value.age(on: date(2025, 3, 1), calendar: calendar), 25)
    }
    func testCalendarTimezoneControlsFutureDayValidation() throws {
        var seoul = calendar
        seoul.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let now = date(2026, 10, 11, hour: 16)
        let birthday = date(2026, 10, 12, hour: 1)
        XCTAssertNoThrow(try User(id: UUID(), email: "p@example.com", name: "김하늘", birthday: birthday,
                                 sex: .male, now: now, calendar: seoul))
        XCTAssertThrowsError(try User(id: UUID(), email: "p@example.com", name: "김하늘", birthday: birthday,
                                     sex: .male, now: now, calendar: calendar))
    }
}
