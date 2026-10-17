import Foundation
import XCTest
@testable import ToDocFeatures

final class SignupBirthdayDisplayTests: XCTestCase {
    func testBirthdayUsesKoreanLabelAndTheSuppliedCalendarTimeZone() {
        let state = SignupScreenState()
        state.calendar = Calendar(identifier: .gregorian)
        state.calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        state.birthday = ISO8601DateFormatter().date(from: "2000-01-01T15:30:00Z")!
        XCTAssertEqual(state.birthdayText, "2000년 1월 2일")
    }

    func testUnselectedBirthdayHasNoInventedLabel() {
        XCTAssertNil(SignupScreenState().birthdayText)
    }
}
