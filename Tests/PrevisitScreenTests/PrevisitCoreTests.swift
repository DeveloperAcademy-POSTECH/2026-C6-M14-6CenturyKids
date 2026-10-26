import XCTest
import ToDocDomain
@testable import PrevisitScreens

final class PrevisitCoreTests: XCTestCase {
    private let patientID = UUID()
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return value
    }
    private func pain(on date: Date, patientID: UUID) throws -> PainRecord {
        try PainRecord(id: UUID(), patientId: patientID, recordedDate: date,
                       location: [.init(bodyPart: .abdomen, bodySide: .unspecified, bodyView: .front)],
                       painBefore: 7, painAfter: 3)
    }

    func testSavedDaysKeepDatesAndOriginalIDsAndRejectForeignPatients() throws {
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let currentPain = try pain(on: today.addingTimeInterval(3600), patientID: patientID)
        let previousPain = try pain(on: yesterday.addingTimeInterval(3600), patientID: patientID)
        let symptom = SymptomRecord(id: UUID(), patientId: patientID, recordedDate: today,
                                    conditionText: "저장한 이야기", symptoms: [])
        XCTAssertTrue(try PrevisitRecordedDays.make(pain: [], symptoms: [], patientID: patientID).isEmpty)
        let days = try PrevisitRecordedDays.make(pain: [previousPain, currentPain], symptoms: [symptom],
                                                patientID: patientID, calendar: calendar)
        XCTAssertEqual(days.count, 2)
        let current = try XCTUnwrap(days.first { $0.recordedDate == today })
        let previous = try XCTUnwrap(days.first { $0.recordedDate == yesterday })
        XCTAssertEqual(current.painRecordIDs, [currentPain.id])
        XCTAssertEqual(current.symptomRecordIDs, [symptom.id])
        XCTAssertEqual(previous.painRecordIDs, [previousPain.id])
        XCTAssertTrue(previous.symptomRecordIDs.isEmpty)
        XCTAssertTrue(current.isSelectable && previous.isSelectable)
        XCTAssertThrowsError(try PrevisitRecordedDays.make(
            pain: [pain(on: today, patientID: UUID())], symptoms: [symptom], patientID: patientID))
        let foreignSymptom = SymptomRecord(id: UUID(), patientId: UUID(), recordedDate: today,
                                          conditionText: nil, symptoms: [])
        XCTAssertThrowsError(try PrevisitRecordedDays.make(
            pain: [currentPain], symptoms: [foreignSymptom], patientID: patientID))
    }

    func testDraftSurvivesCloseBackAndMissingRecordUntilExplicitDiscard() {
        let day = PrevisitDay(id: "saved-day", dateLabel: "10/24", weekday: "토요일",
                              entries: ["저장한 기록"], painRecordIDs: [UUID()])
        let draft = PrevisitDraft(day: day, letter: "  걱정돼요.\n천천히 이야기해 주세요 🙂  ", mood: .carefully)
        let session = PrevisitSession()
        session.next()
        XCTAssertEqual(session.step, .day)
        session.selectDay(day)
        session.next()
        session.draft.letter = draft.letter
        session.next()
        XCTAssertFalse(session.canContinue)
        session.draft.mood = draft.mood
        session.start()
        session.pause()
        XCTAssertFalse(session.isWriting)
        session.start()
        session.next()
        XCTAssertEqual(session.step, .mood)
        XCTAssertEqual(session.draft, draft)
        XCTAssertTrue(session.isWriting)
        session.previous()
        XCTAssertEqual(session.step, .letter)
        session.previous()
        XCTAssertEqual(session.step, .day)
        XCTAssertEqual(session.draft, draft)
        session.next()
        session.next()
        XCTAssertEqual(session.step, .mood)
        session.refreshDays([])
        XCTAssertEqual(session.draft, .init(letter: draft.letter, mood: draft.mood))
        XCTAssertEqual(session.step, .day)
        XCTAssertFalse(session.canContinue)
        session.discard()
        XCTAssertEqual(session.draft, PrevisitDraft())
        XCTAssertFalse(session.hasDraft)
        XCTAssertFalse(session.isWriting)
    }
}
