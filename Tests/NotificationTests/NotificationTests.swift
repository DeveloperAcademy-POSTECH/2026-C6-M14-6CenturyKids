import XCTest
import ToDocDomain
@testable import ToDocNotification

final class NotificationTests: XCTestCase {
    private let patientId = UUID()
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
    // 2026-10-27 15:00 KST
    private let now = Date(timeIntervalSince1970: 1_793_080_800)

    private func notification(hoursAgo: Double, read: Bool = false) -> AppNotification {
        AppNotification(id: UUID(), type: .previsitReminder, title: "진료 전 기록", body: "병원에 가셨나요?",
                        targetId: UUID(), createdAt: now.addingTimeInterval(-hoursAgo * 3600),
                        readAt: read ? now : nil)
    }

    func testSectionsSplitTodayRecentAndOlder() {
        let items = [notification(hoursAgo: 2), notification(hoursAgo: 30, read: true),
                     notification(hoursAgo: 24 * 10, read: true), notification(hoursAgo: 1)]
        let sections = NotificationSectionData.sections(items, now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.title), ["오늘", "최근 7일", "이전 30일"])
        XCTAssertEqual(sections[0].items.map(\.timeLabel), ["1시간 전", "2시간 전"]) // 최근 알림부터
        XCTAssertEqual(sections.map(\.hasUnread), [true, false, false])
        XCTAssertEqual(sections[1].items.first?.timeLabel, "1일 전")
    }

    func testTimeLabel() {
        XCTAssertEqual(NotificationSectionData.timeLabel(now.addingTimeInterval(-30), now: now), "방금 전")
        XCTAssertEqual(NotificationSectionData.timeLabel(now.addingTimeInterval(-5 * 60), now: now), "5분 전")
        XCTAssertEqual(NotificationSectionData.timeLabel(now.addingTimeInterval(-3 * 86400), now: now), "3일 전")
    }

    func testFileRepositorySavesReadsMarksAndDropsAfter30Days() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileNotificationRepository(directory: directory, now: { self.now })
        let fresh = notification(hoursAgo: 1)
        try await repository.save(notification: fresh, for: patientId)
        try await repository.save(notification: notification(hoursAgo: 24 * 31), for: patientId)

        let found = try await repository.findByUserId(patientId)
        XCTAssertEqual(found.map(\.id), [fresh.id])
        let unreadBefore = try await repository.countUnreadByUserId(patientId)
        XCTAssertEqual(unreadBefore, 1)
        let otherPatient = try await repository.findByUserId(UUID())
        XCTAssertTrue(otherPatient.isEmpty)

        try await repository.markAsRead(fresh.id)
        let unreadAfter = try await repository.countUnreadByUserId(patientId)
        XCTAssertEqual(unreadAfter, 0)
        let byId = try await repository.findById(fresh.id)
        XCTAssertNotNil(byId?.readAt)
    }
}
