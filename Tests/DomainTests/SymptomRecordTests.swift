import Foundation
import XCTest
import ToDocDomain

final class SymptomRecordTests: XCTestCase {
    private func entry(id: UUID = UUID(), severity: Double = 5, rawLocationText: String? = nil) throws -> SymptomEntry {
        try SymptomEntry(id: id, symptomType: .numbness, bodyPart: .armHand, bodySide: .left,
                         rawLocationText: rawLocationText,
                         durationMinutes: nil, occurrenceCount: nil, severity: severity, detail: nil)
    }
    func testAddAndRemoveUseIdentityWithoutOverwritingDuplicates() throws {
        let first = try entry(), second = try entry()
        let id = UUID(), date = Date(timeIntervalSince1970: 1_000)
        var record = SymptomRecord(id: id, recordedDate: date, symptoms: [first])
        record.addSymptomEntry(try entry(id: first.id, severity: 10))
        XCTAssertEqual(record.symptoms.count, 1)
        XCTAssertEqual(record.symptoms.first?.severity, 5)
        record.addSymptomEntry(second)
        record.removeSymptomEntry(id: UUID())
        XCTAssertEqual(record.symptoms.map(\.id), [first.id, second.id])
        record.removeSymptomEntry(id: first.id)
        XCTAssertEqual(record.symptoms.map(\.id), [second.id])
        record.removeSymptomEntry(id: second.id)
        XCTAssertTrue(record.symptoms.isEmpty)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.recordedDate, date)
    }
    func testRecordPreservesFractionalSeverityAndOriginalLocationText() throws {
        let first = try entry(severity: 3.5, rawLocationText: "  왼쪽 손끝이 저려요  ")
        var record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: [first])
        record.addSymptomEntry(try entry(id: first.id, severity: 9.5, rawLocationText: "다른 표현"))
        let second = try entry(severity: 0.5)
        record.addSymptomEntry(second)
        XCTAssertEqual(record.symptoms.map(\.severity), [3.5, 0.5])
        XCTAssertEqual(record.symptoms.map(\.rawLocationText), ["  왼쪽 손끝이 저려요  ", nil])
        record.removeSymptomEntry(id: first.id)
        XCTAssertEqual(record.symptoms.first?.id, second.id)
        XCTAssertEqual(record.symptoms.first?.severity, 0.5)
        XCTAssertNil(record.symptoms.first?.rawLocationText)
    }
    func testCreationKeepsFirstEntryForDuplicateId() throws {
        let first = try entry()
        let record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: [first, try entry(id: first.id, severity: 10)])
        XCTAssertEqual(record.symptoms.count, 1)
        XCTAssertEqual(record.symptoms.first?.severity, 5)
    }
}
