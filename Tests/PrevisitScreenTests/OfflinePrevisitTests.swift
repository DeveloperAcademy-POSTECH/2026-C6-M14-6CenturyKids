import Foundation
import Testing
import ToDocDomain
@testable import PrevisitScreens

@MainActor
struct OfflinePrevisitTests {
    @Test func draftAndStepSurviveRecreationAndDiscard() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "previsit-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "draft.json")
        let session = PrevisitSession(storageURL: url)
        session.selectDay(PrevisitDay(id: "today", dateLabel: "오늘", weekday: "", entries: [], recordedDate: Date()))
        session.next()
        session.draft.letter = "네트워크 없이 작성한 초안"
        session.next()
        session.draft.mood = .comfortable
        let restored = PrevisitSession(storageURL: url)
        #expect(restored.step == .mood)
        #expect(restored.draft.letter == "네트워크 없이 작성한 초안")
        #expect(restored.draft.mood == .comfortable)
        #expect(restored.persistenceError == nil)
        restored.discard()
        #expect(!PrevisitSession(storageURL: url).hasDraft)
    }

    @Test func boothCanSaveMultipleLettersOnSameDayWithoutPriorHealthRecords() async {
        var saved: [PrevisitRecord] = []
        let model = PrevisitLetterViewModel(patientID: UUID(), save: { saved.append($0) }, allowsMultiplePerDay: true)
        let day = PrevisitDay(id: "today", dateLabel: "오늘", weekday: "", entries: [], recordedDate: Date())
        #expect(day.isSelectable)
        let draft = PrevisitDraft(day: day, letter: "진료 전 질문", mood: .unsure)
        #expect(await model.send(draft, to: "선생님") != nil)
        #expect(await model.send(draft, to: "선생님") != nil)
        #expect(saved.count == 2)
        #expect(saved[0].id != saved[1].id)
    }
}
