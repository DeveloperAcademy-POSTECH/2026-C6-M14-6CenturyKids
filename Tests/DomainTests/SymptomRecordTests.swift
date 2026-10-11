import Foundation
import XCTest
import ToDocDomain

final class SymptomRecordTests: XCTestCase {
    private func entry(id: UUID = UUID(), severity: Int = 5) throws -> SymptomEntry {
        try SymptomEntry(id: id, symptomType: .numbness, bodyPart: .armHand, bodySide: .left,
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
    func testCreationKeepsFirstEntryForDuplicateId() throws {
        let first = try entry()
        let record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: [first, try entry(id: first.id, severity: 10)])
        XCTAssertEqual(record.symptoms.count, 1)
        XCTAssertEqual(record.symptoms.first?.severity, 5)
    }
}
