import Foundation
import XCTest
@testable import AuthPresentation
@testable import ToDocDomain

@MainActor
final class SignupDateRulesTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func model(now: String, zone: TimeZone? = nil) -> SignupViewModel {
        let instant = date(now)
        let model = SignupViewModel(now: { instant }, timeZone: zone ?? utc)
        model.name = "김하늘"
        model.sex = .female
        return model
    }

    func testLeapBirthdayWaitsUntilMarchFirstInNonLeapYear() throws {
        let value = model(now: "2025-02-28T12:00:00Z")
        value.birthday = date("2000-02-29T00:00:00Z")
        XCTAssertEqual(value.age, 24)
        let user = try User(id: UUID(), email: "p@example.com", name: value.name,
                            birthday: value.birthday!, sex: .female,
                            now: date("2025-02-28T12:00:00Z"), calendar: value.calendar)
        XCTAssertEqual(user.age(on: date("2025-02-28T12:00:00Z"), calendar: value.calendar), 24)
        let march = model(now: "2025-03-01T00:00:00Z")
        march.birthday = value.birthday
        XCTAssertEqual(march.age, 25)
    }

    func testBirthdayBoundaryUsesInjectedClock() {
        for (now, expected) in [("2026-10-10T23:59:59Z", 25), ("2026-10-11T00:00:00Z", 26),
                                ("2026-10-12T00:00:00Z", 26)] {
            let value = model(now: now)
            value.birthday = date("2000-10-11T00:00:00Z")
            XCTAssertEqual(value.age, expected)
        }
    }

    func testSameInstantHasDifferentBirthdayInSeoulAndUTC() {
        let seoul = model(now: "2026-10-11T16:00:00Z", zone: TimeZone(secondsFromGMT: 9 * 3600)!)
        let universal = model(now: "2026-10-11T16:00:00Z")
        for value in [seoul, universal] { value.birthday = date("2000-10-12T00:00:00Z") }
        XCTAssertEqual(seoul.age, 26)
        XCTAssertEqual(universal.age, 25)
        XCTAssertEqual(seoul.calendar.identifier, .gregorian)
    }

    func testTodayLaterTimeIsAllowedButFutureDayIsRejected() {
        let value = model(now: "2026-10-11T16:00:00Z", zone: TimeZone(secondsFromGMT: 9 * 3600)!)
        value.birthday = date("2026-10-12T01:00:00Z")
        XCTAssertNil(value.patientInfoError)
        XCTAssertEqual(value.age, 0)
        value.birthday = date("2026-10-12T16:00:00Z")
        XCTAssertNotNil(value.patientInfoError)
        XCTAssertNil(value.age)
    }

    func testMissingBirthdayHasNoAgeAndCannotProceed() {
        let value = model(now: "2026-10-11T00:00:00Z")
        XCTAssertNil(value.age)
        XCTAssertNotNil(value.patientInfoError)
    }
}
