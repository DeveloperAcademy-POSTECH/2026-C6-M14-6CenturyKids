import Foundation
import XCTest
import ToDocDomain

final class PainRecordTests: XCTestCase {
    private let patientId = UUID()
    private var front: BodyLocation { .init(bodyPart: .neck, bodySide: .center, bodyView: .front) }
    private var back: BodyLocation { .init(bodyPart: .neck, bodySide: .center, bodyView: .back) }
    private func record(before: Int = 7, after: Int = 3, locations: [BodyLocation]? = nil) throws -> PainRecord {
        try PainRecord(id: UUID(), patientId: patientId, recordedDate: Date(timeIntervalSince1970: 1_000),
                       location: locations ?? [front], painBefore: before, painAfter: after)
    }
    func testBothPainValuesAcceptZeroAndTenAndRejectOutside() throws {
        for value in [0, 10] {
            XCTAssertNoThrow(try record(before: value))
            XCTAssertNoThrow(try record(after: value))
        }
        for (value, expected) in [(-1, PainRecordValueError.belowMinimum), (11, .aboveMaximum)] {
            XCTAssertThrowsError(try record(before: value)) { XCTAssertEqual($0 as? PainRecordValueError, expected) }
            XCTAssertThrowsError(try record(after: value)) { XCTAssertEqual($0 as? PainRecordValueError, expected) }
        }
    }
    func testPainChangeRetainsReductionAndIncreaseSigns() throws {
        XCTAssertEqual(try record(before: 7, after: 3).painChange, 4)
        XCTAssertEqual(try record(before: 3, after: 7).painChange, -4)
        XCTAssertEqual(try record(before: 0, after: 0).painChange, 0)
    }
    func testEmptyLocationsAreRejectedWithTypedError() {
        XCTAssertThrowsError(try record(locations: [])) {
            XCTAssertEqual($0 as? PainLocationValidationError, .empty)
        }
    }
    func testDuplicateLocationsDoNotAllowRemovingTheLastDistinctLocation() throws {
        var value = try record(locations: [front, front])
        XCTAssertEqual(value.location, [front])
        value.addLocation(front)
        value.removeLocation(front)
        XCTAssertEqual(value.location, [front])
    }
    func testLocationMutationPreservesPatientIdentityDateAndScores() throws {
        var value = try record()
        let id = value.id, date = value.recordedDate
        value.addLocation(back)
        value.addLocation(back)
        XCTAssertEqual(value.location, [front, back])
        value.removeLocation(front)
        XCTAssertEqual(value.location, [back])
        value.removeLocation(front)
        value.removeLocation(back)
        XCTAssertEqual(value.location, [back])
        XCTAssertEqual(value.id, id)
        // 부위를 편집하는 동작은 기록의 소유 환자를 변경하지 않습니다.
        XCTAssertEqual(value.patientId, patientId)
        XCTAssertEqual(value.recordedDate, date)
        XCTAssertEqual(value.painBefore, 7)
        XCTAssertEqual(value.painAfter, 3)
    }
    func testLocationIdentityUsesPartSideAndView() throws {
        let left = BodyLocation(bodyPart: .neck, bodySide: .left, bodyView: .front)
        let head = BodyLocation(bodyPart: .headFace, bodySide: .center, bodyView: .front)
        var value = try record()
        for location in [left, head, back] { value.addLocation(location) }
        XCTAssertEqual(value.location, [front, left, head, back])
    }
}
