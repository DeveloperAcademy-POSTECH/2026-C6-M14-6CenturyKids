import Foundation
import XCTest
import ToDocDomain

final class SymptomEntryTests: XCTestCase {
    private func entry(durationMinutes: Int? = nil, occurrenceCount: Int? = nil,
                       severity: Int? = nil, detail: String? = nil) throws -> SymptomEntry {
        try SymptomEntry(id: UUID(), symptomType: .fatigueWeakness, bodyPart: nil, bodySide: nil,
                         durationMinutes: durationMinutes, occurrenceCount: occurrenceCount,
                         severity: severity, detail: detail)
    }
    func testUnansweredOptionalFieldsRemainNil() throws {
        let value = try entry()
        XCTAssertNil(value.bodyPart)
        XCTAssertNil(value.bodySide)
        XCTAssertNil(value.durationMinutes)
        XCTAssertNil(value.occurrenceCount)
        XCTAssertNil(value.severity)
        XCTAssertNil(value.detail)
    }
    func testDurationMinutesRangeOnCreationAndUpdate() throws {
        var value = try entry()
        for number in [10, 1440] {
            XCTAssertEqual(try entry(durationMinutes: number).durationMinutes, number)
            try value.updateDurationMinutes(number)
            XCTAssertEqual(value.durationMinutes, number)
        }
        for number in [9, 1441] {
            XCTAssertThrowsError(try entry(durationMinutes: number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidDuration)
            }
            XCTAssertThrowsError(try value.updateDurationMinutes(number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidDuration)
            }
            XCTAssertEqual(value.durationMinutes, 1440)
        }
    }
    func testOccurrenceCountRangeOnCreationAndUpdate() throws {
        var value = try entry()
        for number in [1, 100] {
            XCTAssertEqual(try entry(occurrenceCount: number).occurrenceCount, number)
            try value.updateOccurrenceCount(number)
            XCTAssertEqual(value.occurrenceCount, number)
        }
        for number in [0, 101] {
            XCTAssertThrowsError(try entry(occurrenceCount: number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidOccurrenceCount)
            }
            XCTAssertThrowsError(try value.updateOccurrenceCount(number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidOccurrenceCount)
            }
            XCTAssertEqual(value.occurrenceCount, 100)
        }
    }
    func testSeverityRangeOnCreationAndUpdate() throws {
        var value = try entry()
        for number in [0, 10] {
            XCTAssertEqual(try entry(severity: number).severity, number)
            try value.updateSeverity(number)
            XCTAssertEqual(value.severity, number)
        }
        for number in [-1, 11] {
            XCTAssertThrowsError(try entry(severity: number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidSeverity)
            }
            XCTAssertThrowsError(try value.updateSeverity(number)) {
                XCTAssertEqual($0 as? SymptomValueError, .invalidSeverity)
            }
            XCTAssertEqual(value.severity, 10)
        }
    }
    func testDetailCountsCharactersAndRejectedUpdatePreservesText() throws {
        let allowed = String(repeating: "👩‍👩‍👧‍👧", count: 300)
        var value = try entry(detail: allowed)
        let id = value.id
        let tooLong = allowed + "가"
        XCTAssertThrowsError(try entry(detail: tooLong)) { XCTAssertEqual($0 as? SymptomValueError, .detailTooLong) }
        XCTAssertThrowsError(try value.updateDetail(tooLong)) { XCTAssertEqual($0 as? SymptomValueError, .detailTooLong) }
        XCTAssertEqual(value.detail, allowed)
        try value.updateDetail("")
        XCTAssertEqual(value.detail, "")
        XCTAssertEqual(value.id, id)
        XCTAssertEqual(value.symptomType, .fatigueWeakness)
    }
}
