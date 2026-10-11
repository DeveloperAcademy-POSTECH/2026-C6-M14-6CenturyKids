import XCTest
@testable import ToDocDomain

final class NotificationTypeTests: XCTestCase {
    func testStoredValuesDecodeToNotificationKinds() {
        XCTAssertEqual(NotificationType(rawValue: "exerciseGoalCreated"), .exerciseGoalCreated)
        XCTAssertEqual(NotificationType(rawValue: "commentArrived"), .commentArrived)
        XCTAssertEqual(NotificationType(rawValue: "intakeRecordReminder"), .intakeRecordReminder)
    }

    func testUnknownStoredValueIsRejectedInsteadOfBecomingAnUnrelatedNotification() {
        XCTAssertNil(NotificationType(rawValue: "unknownFutureNotification"))
        XCTAssertNil(NotificationType(rawValue: ""))
    }

    func testAllNotificationKindsSurviveStorageRoundTrip() {
        for type in NotificationType.allCases {
            XCTAssertEqual(NotificationType(rawValue: type.rawValue), type)
        }
    }
}
