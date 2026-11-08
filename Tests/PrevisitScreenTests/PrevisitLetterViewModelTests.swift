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

    func testSendPersistsDomainAndAllowsOnlyOnePerDay() async throws {
        var saved: [PrevisitRecord] = []
        let model = PrevisitLetterViewModel(patientID: patientID, save: { saved.append($0) })
        let draft = PrevisitDraft(day: day, letter: "하고 싶은 말", mood: .comfortable)
        XCTAssertFalse(model.hasSentToday)
        let first = await model.send(draft, to: "선생님")
        XCTAssertTrue(model.hasSentToday)
        let second = await model.send(draft, to: "선생님")
        XCTAssertNotNil(first)
        XCTAssertNil(second)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.patientId, patientID)
        XCTAssertEqual(saved.first?.selectedDate, day.recordedDate)
        XCTAssertEqual(saved.first?.memo, draft.letter)
        XCTAssertEqual(saved.first?.stateOfMind, .comfortable)
        XCTAssertEqual(model.letters.count, 1)
        XCTAssertEqual(model.badges(model.letters[0]), ["통증 7점→6점"])
    }

    func testLetterSentYesterdayDoesNotBlockToday() async throws {
        let sentAt = Date(timeIntervalSince1970: 1793314800)
        var today = sentAt
        let record = try PrevisitRecord(id: UUID(), patientId: patientID, selectedDate: sentAt, memo: nil,
                                        stateOfMind: .unsure, submittedAt: sentAt)
        let model = PrevisitLetterViewModel(patientID: patientID, now: { today }, load: { [record] })
        await model.load(days: [], doctorName: "선생님")
        XCTAssertTrue(model.hasSentToday)
        today = sentAt.addingTimeInterval(24 * 60 * 60)
        XCTAssertFalse(model.hasSentToday)
    }

    func testFailedSendDoesNotCreateLetterAndCanRetry() async {
        var fails = true
        var events: [(name: String, properties: [String: Any])] = []
        let model = PrevisitLetterViewModel(patientID: patientID, save: { _ in
            XCTAssertEqual(events.last?.name, "previsit_submit_attempted")
            if fails { throw URLError(.notConnectedToInternet) }
        })
        let draft = PrevisitDraft(day: day, letter: "원문", mood: .unsure)
        let session = PrevisitSession(step: .mood, draft: draft) { events.append(($0, $1)) }
        session.analytics.screenAppeared(step: .mood)
        let failed = await model.send(draft, to: "선생님") { session.analytics.startSubmission() }
        XCTAssertNil(failed)
        XCTAssertTrue(model.letters.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isSubmitting)
        fails = false
        let retried = await model.send(draft, to: "선생님") { session.analytics.startSubmission() }
        XCTAssertNotNil(retried)
        XCTAssertNil(model.errorMessage)
        let blocked = await model.send(draft, to: "선생님") { session.analytics.startSubmission() }
        XCTAssertNil(blocked)

        let submits = events.filter { $0.name.hasPrefix("previsit_submit_") }
        XCTAssertEqual(submits.map(\.name), [
            "previsit_submit_attempted", "previsit_submit_failed",
            "previsit_submit_attempted", "previsit_submit_succeeded"
        ])
        guard submits.count == 4 else { return }
        let attemptIDs = submits.compactMap { $0.properties["attempt_id"] as? String }
        XCTAssertEqual(attemptIDs.count, 4)
        XCTAssertEqual(Set(attemptIDs).count, 1)
        let requestIDs = submits.compactMap { $0.properties["request_id"] as? String }
        XCTAssertEqual(requestIDs.count, 4)
        XCTAssertEqual(Set(requestIDs.prefix(2)).count, 1)
        XCTAssertEqual(Set(requestIDs.suffix(2)).count, 1)
        XCTAssertNotEqual(requestIDs.first, requestIDs.last)
        XCTAssertEqual(submits.compactMap { $0.properties["is_retry"] as? Bool }, [false, false, true, true])
        XCTAssertEqual(submits[1].properties["error_code"] as? String, "network_error")
        XCTAssertNotNil(submits[3].properties["request_duration_ms"] as? Int)
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

    func testDetailReloadsEveryRecordWhileBadgeUsesRepresentativePain() async throws {
        let date = day.recordedDate!
        let pains = try [(7, 4), (3, 5), (8, 2)].enumerated().map { index, scores in
            try PainRecord(id: UUID(), patientId: patientID,
                           recordedDate: date.addingTimeInterval(Double(index * 60)),
                           location: [.init(bodyPart: .abdomen, bodySide: .unspecified, bodyView: .front)],
                           painBefore: scores.0, painAfter: scores.1)
        }
        let symptom = SymptomRecord(id: UUID(), patientId: patientID, recordedDate: date,
                                    conditionText: "속이 불편해요", symptoms: [])
        let fullDay = try XCTUnwrap(PrevisitRecordedDays.make(pain: pains, symptoms: [symptom], patientID: patientID).first)
        let record = try PrevisitRecord(patientId: patientID, selectedDate: date, memo: "메모", stateOfMind: .candid)
        var requestedDate: Date?
        let model = PrevisitLetterViewModel(patientID: patientID, load: { [record] }, loadDay: {
            requestedDate = $0
            return fullDay
        })
        await model.load(days: [day], doctorName: "선생님")
        await model.loadDetail(record.id)
        let detail = try XCTUnwrap(model.letter(record.id))
        XCTAssertEqual(requestedDate, date)
        XCTAssertEqual(detail.draft.day?.painRecordIDs, pains.map(\.id))
        XCTAssertEqual(detail.draft.day?.symptomRecordIDs, [symptom.id])
        XCTAssertEqual(detail.draft.day?.entries, fullDay.entries)
        XCTAssertEqual(detail.draft.day?.entries.count, 5)
        XCTAssertEqual(model.badges(detail), ["통증 3점→5점"])
    }

    func testInvalidMemoIsNotSaved() async {
        var saves = 0
        let model = PrevisitLetterViewModel(patientID: patientID, save: { _ in saves += 1 })
        let id = await model.send(.init(day: day, letter: String(repeating: "가", count: 201), mood: .candid), to: "선생님")
        XCTAssertNil(id)
        XCTAssertEqual(saves, 0)
    }
}
