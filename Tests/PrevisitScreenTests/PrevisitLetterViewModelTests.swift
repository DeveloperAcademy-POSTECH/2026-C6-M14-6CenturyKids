import XCTest
import ToDocDomain
@testable import PrevisitScreens

@MainActor
final class PrevisitLetterViewModelTests: XCTestCase {
    private let patientID = UUID()
    private var day: PrevisitDay {
        PrevisitDay(id: "day", dateLabel: "10/30", weekday: "금요일", entries: ["통증"],
                    recordedDate: Date(timeIntervalSince1970: 1793314800), painBefore: 7, painAfter: 6)
    }

    func testSendPersistsDomainAndNeverOverwritesSentRecord() async throws {
        var saved: [PrevisitRecord] = []
        let model = PrevisitLetterViewModel(patientID: patientID, save: { saved.append($0) })
        let draft = PrevisitDraft(day: day, letter: "하고 싶은 말", mood: .comfortable)
        let first = await model.send(draft, to: "선생님")
        let second = await model.send(draft, to: "선생님")
        XCTAssertNotNil(first)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(saved.first?.patientId, patientID)
        XCTAssertEqual(saved.first?.selectedDate, day.recordedDate)
        XCTAssertEqual(saved.first?.memo, draft.letter)
        XCTAssertEqual(saved.first?.stateOfMind, .comfortable)
        XCTAssertEqual(model.letters.count, 2)
        XCTAssertEqual(model.badges(model.letters[0]), ["통증 7점→6점"])
    }

    func testFailedSendDoesNotCreateLetterAndCanRetry() async {
        enum Failure: Error { case offline }
        var fails = true
        let model = PrevisitLetterViewModel(patientID: patientID, save: { _ in if fails { throw Failure.offline } })
        let draft = PrevisitDraft(day: day, letter: "원문", mood: .unsure)
        let failed = await model.send(draft, to: "선생님")
        XCTAssertNil(failed)
        XCTAssertTrue(model.letters.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isSubmitting)
        fails = false
        let retried = await model.send(draft, to: "선생님")
        XCTAssertNotNil(retried)
        XCTAssertNil(model.errorMessage)
    }

    func testLoadRestoresMemoMoodAndSelectedDay() async throws {
        let record = try PrevisitRecord(patientId: patientID, selectedDate: day.recordedDate!,
                                       memo: "\n 원문", stateOfMind: .slowly)
        let model = PrevisitLetterViewModel(patientID: patientID, load: { [record] })
        await model.load(days: [day], doctorName: "선생님")
        XCTAssertEqual(model.latest?.id, record.id)
        XCTAssertEqual(model.latest?.draft.day, day)
        XCTAssertEqual(model.latest?.draft.mood, .slowly)
        XCTAssertEqual(model.latest?.draft.letter, "\n 원문")
        XCTAssertEqual(model.preview(model.latest!), "원문")
    }

    func testInvalidMemoIsNotSaved() async {
        var saves = 0
        let model = PrevisitLetterViewModel(patientID: patientID, save: { _ in saves += 1 })
        let id = await model.send(.init(day: day, letter: String(repeating: "가", count: 201), mood: .candid), to: "선생님")
        XCTAssertNil(id)
        XCTAssertEqual(saves, 0)
    }
}
