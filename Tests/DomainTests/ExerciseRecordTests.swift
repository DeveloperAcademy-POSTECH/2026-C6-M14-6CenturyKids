import Foundation
import XCTest
@testable import ToDocDomain

final class ExerciseRecordTests: XCTestCase {
    func testCompletionCancellationAndRecompletionUpdateTimestamp() {
        let id = UUID(), goalId = UUID(), date = Date(timeIntervalSince1970: 1_000)
        var record = ExerciseRecord(id: id, exerciseGoalId: goalId, date: date, recordedAt: nil, isCompleted: false)
        let first = Date(timeIntervalSince1970: 2_000), second = Date(timeIntervalSince1970: 3_000)
        record.toggleCompletion(at: first)
        XCTAssertTrue(record.isCompleted)
        XCTAssertEqual(record.recordedAt, first)
        record.toggleCompletion(at: second)
        XCTAssertFalse(record.isCompleted)
        XCTAssertNil(record.recordedAt)
        record.toggleCompletion(at: second)
        XCTAssertTrue(record.isCompleted)
        XCTAssertEqual(record.recordedAt, second)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.exerciseGoalId, goalId)
        XCTAssertEqual(record.date, date)
    }
    func testRestoredTimestampIsPreservedUntilToggled() {
        let saved = Date(timeIntervalSince1970: 2_000)
        var record = ExerciseRecord(id: UUID(), exerciseGoalId: UUID(), date: Date(timeIntervalSince1970: 1_000),
                                    recordedAt: saved, isCompleted: true)
        XCTAssertEqual(record.recordedAt, saved)
        record.toggleCompletion()
        XCTAssertFalse(record.isCompleted)
        XCTAssertNil(record.recordedAt)
    }
    func testPublicToggleRecordsCurrentTime() throws {
        var record = ExerciseRecord(id: UUID(), exerciseGoalId: UUID(), date: Date(timeIntervalSince1970: 1_000),
                                    recordedAt: nil, isCompleted: false)
        let before = Date()
        record.toggleCompletion()
        let after = Date()
        let timestamp = try XCTUnwrap(record.recordedAt)
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, after)
    }
}
