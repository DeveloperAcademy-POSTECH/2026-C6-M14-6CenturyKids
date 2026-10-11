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
    func testCareCallKeepsConstipationAndDiarrheaAsSeparateSymptoms() throws {
        let constipation = try SymptomEntry(
            id: UUID(), symptomType: XCTUnwrap(SymptomType(rawValue: "constipation")),
            bodyPart: nil, bodySide: nil, durationMinutes: nil, occurrenceCount: nil,
            severity: 3.5, detail: "어제부터요")
        let diarrhea = try SymptomEntry(
            id: UUID(), symptomType: XCTUnwrap(SymptomType(rawValue: "diarrhea")),
            bodyPart: nil, bodySide: nil, durationMinutes: nil, occurrenceCount: 3,
            severity: 5.5, detail: "하루 세 번이요")
        var record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: [constipation])
        record.addSymptomEntry(diarrhea)
        XCTAssertEqual(record.symptoms.map(\.symptomType.rawValue), ["constipation", "diarrhea"])
        XCTAssertEqual(record.symptoms.map(\.severity), [3.5, 5.5])
        XCTAssertEqual(record.symptoms.map(\.occurrenceCount), [nil, 3])
        XCTAssertEqual(record.symptoms.map(\.detail), ["어제부터요", "하루 세 번이요"])
    }

    func testCareCallKeepsSeparateLocationsForTheSameSymptom() throws {
        let locations: [(BodyPart, BodySide, String)] = [
            (.armHand, .left, "왼손"), (.legFoot, .right, "오른발"), (.armHand, .both, "양손")
        ]
        let entries = try locations.map { part, side, rawText in
            try SymptomEntry(id: UUID(), symptomType: .numbness, bodyPart: part, bodySide: side,
                             rawLocationText: rawText, durationMinutes: 30, occurrenceCount: nil,
                             severity: 3.5, detail: "삼십 분 동안 저렸어요")
        }
        let record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: entries)
        XCTAssertEqual(record.symptoms.map(\.symptomType), [.numbness, .numbness, .numbness])
        XCTAssertEqual(record.symptoms.map(\.bodyPart), [.armHand, .legFoot, .armHand])
        XCTAssertEqual(record.symptoms.map(\.bodySide), [.left, .right, .both])
        XCTAssertEqual(record.symptoms.map(\.rawLocationText), ["왼손", "오른발", "양손"])
        XCTAssertEqual(record.symptoms.map(\.severity), [3.5, 3.5, 3.5])
        XCTAssertEqual(record.symptoms.map(\.durationMinutes), [30, 30, 30])
        XCTAssertEqual(record.symptoms.map(\.detail), Array(repeating: "삼십 분 동안 저렸어요", count: 3))
    }

    func testCareCallKeepsUnknownLocationWithoutInventingAnEnumValue() throws {
        let entry = try SymptomEntry(
            id: UUID(), symptomType: XCTUnwrap(SymptomType(rawValue: "rashItching")),
            bodyPart: nil, bodySide: nil, rawLocationText: "겨드랑이",
            durationMinutes: nil, occurrenceCount: nil, severity: nil, detail: "가려워요")
        let record = SymptomRecord(id: UUID(), recordedDate: Date(timeIntervalSince1970: 1_000),
                                   symptoms: [entry])
        let saved = try XCTUnwrap(record.symptoms.first)
        XCTAssertNil(saved.bodyPart)
        XCTAssertNil(saved.bodySide)
        XCTAssertEqual(saved.rawLocationText, "겨드랑이")
        XCTAssertEqual(saved.detail, "가려워요")
    }
}
