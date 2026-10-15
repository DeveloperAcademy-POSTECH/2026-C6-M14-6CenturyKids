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

    func testUnreadNotificationKeepsNilWithoutInventedTimestamp() {
        let notification = AppNotification(id: UUID(), type: .commentArrived,
            title: "새 메시지", body: "기록을 확인했습니다.", targetId: UUID(),
            createdAt: Date(timeIntervalSince1970: 100), readAt: nil)
        XCTAssertNil(notification.readAt)
    }

    func testReadNotificationPreservesActualTimestamp() {
        let readAt = Date(timeIntervalSince1970: 200)
        let notification = AppNotification(id: UUID(), type: .intakeRecordReminder,
            title: "식사 기록", body: "식사를 기록해 주세요.", targetId: UUID(),
            createdAt: Date(timeIntervalSince1970: 100), readAt: readAt)
        XCTAssertEqual(notification.readAt, readAt)
    }
}
