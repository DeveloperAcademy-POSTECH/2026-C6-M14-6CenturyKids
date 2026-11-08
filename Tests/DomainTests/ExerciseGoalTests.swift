import Foundation
import XCTest
@testable import ToDocDomain

final class ExerciseGoalTests: XCTestCase {
    // 목표의 주인(환자)과 목표를 지정한 의사는 서로 다른 ID입니다.
    // 날짜 검색·횟수 검증도 현재 Model의 필수 관계를 갖춘 자료로 실행합니다.
    private let patientId = UUID()
    private let doctorId = UUID()
    private var utc: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }
    private func date(_ day: Int, hour: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
    private func goal(target: Int) throws -> ExerciseGoal {
        try ExerciseGoal(id: UUID(), patientId: patientId, doctorId: doctorId, year: 2026, month: 10, targetCount: target, exerciseRecords: [])
    }
    func testTargetRangeIncludesZeroAndThirtyOneAndRejectsOutside() throws {
        for target in [0, 31] { XCTAssertEqual(try goal(target: target).targetCount, target) }
        for (target, expected) in [(-1, TargetCountValidationError.belowMinimum), (32, .aboveMaximum), (100, .aboveMaximum)] {
            XCTAssertThrowsError(try goal(target: target)) { XCTAssertEqual($0 as? TargetCountValidationError, expected) }
        }
    }
    func testDateLookupReturnsFirstSameDayAndNilForMissingDay() throws {
        let id = UUID()
        let first = ExerciseRecord(id: UUID(), exerciseGoalId: id, date: date(11, hour: 1), recordedAt: nil, isCompleted: false)
        let second = ExerciseRecord(id: UUID(), exerciseGoalId: id, date: date(11, hour: 20), recordedAt: nil, isCompleted: false)
        let goal = try ExerciseGoal(id: id, patientId: patientId, doctorId: doctorId, year: 2026, month: 10, targetCount: 10, exerciseRecords: [first, second])
        XCTAssertEqual(goal.findRecordByDate(date: date(11, hour: 12), calendar: utc)?.id, first.id)
        XCTAssertNil(goal.findRecordByDate(date: date(12, hour: 0), calendar: utc))
        XCTAssertEqual(goal.findRecordByDate(date: first.date)?.id, first.id)
    }
    func testDateLookupRespectsTimezoneAtMidnight() throws {
        let id = UUID()
        let record = ExerciseRecord(id: UUID(), exerciseGoalId: id, date: date(11, hour: 16), recordedAt: nil, isCompleted: false)
        let goal = try ExerciseGoal(id: id, patientId: patientId, doctorId: doctorId, year: 2026, month: 10, targetCount: 1, exerciseRecords: [record])
        var seoul = utc
        seoul.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        XCTAssertEqual(goal.findRecordByDate(date: date(12, hour: 1), calendar: seoul)?.id, record.id)
        XCTAssertNil(goal.findRecordByDate(date: date(12, hour: 1), calendar: utc))
    }
    func testEmptyGoalHasNoMatchingRecord() throws {
        XCTAssertNil(try goal(target: 0).findRecordByDate(date: date(11, hour: 0)))
    }
}
