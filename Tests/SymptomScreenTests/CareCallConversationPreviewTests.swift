import XCTest
@testable import ToDocFeatures

final class CareCallConversationPreviewTests: XCTestCase {
    func testChatEntryStartsAtSymptomSelection() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        XCTAssertEqual(session.stage, .conversation)
        XCTAssertEqual(session.mode, .text)
        XCTAssertEqual(session.question.step, .symptoms)
    }

    func testManualPathReachesCountDurationAndImpactBeforeSummary() {
        var session = bowelSession()
        XCTAssertEqual(session.question.step, .discomfort)
        session.advance()
        XCTAssertEqual(session.question.step, .discomfort, "A visible default is not an answer.")
        session.draft.discomfort = 0
        session.draft.answeredSteps.insert(.discomfort)
        session.advance()
        XCTAssertEqual(session.question.step, .frequency)
        session.draft.frequencyIndex = 0
        session.draft.answeredSteps.insert(.frequency)
        session.advance()
        XCTAssertEqual(session.question.step, .duration)
        session.draft.hours = 0
        session.draft.minutes = 5
        session.draft.answeredSteps.insert(.duration)
        session.advance()
        XCTAssertEqual(session.question.step, .dailyLife)
        session.skip()
        XCTAssertEqual(session.stage, .loading)
        XCTAssertEqual(session.summaryItems.count, 1)
        XCTAssertTrue(session.summaryItems.first?.detail.contains("0번") == true)
        XCTAssertTrue(session.summaryItems.first?.detail.contains("5분") == true)
        XCTAssertEqual(session.summaryItems.first?.discomfort, 0)
    }

    func testModeRoundTripKeepsQuestionAndTypedDraft() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.bowel, .other]
        session.advance()
        XCTAssertEqual(session.question.step, .other)
        session.draft.other = "관절이 아파요"
        session.draft.answeredSteps.insert(.other)
        let question = session.question
        session.switchMode()
        XCTAssertEqual(session.mode, .voice)
        XCTAssertEqual(session.question, question)
        session.switchMode()
        XCTAssertEqual(session.mode, .text)
        XCTAssertEqual(session.draft.other, "관절이 아파요")
        XCTAssertTrue(session.draft.canContinue(.other))
    }

    func testModeRoundTripKeepsCountAndDurationSelection() {
        var session = bowelSession()
        session.draft.answeredSteps.insert(.discomfort)
        session.advance()
        session.draft.frequencyIndex = 11
        session.draft.answeredSteps.insert(.frequency)
        session.switchMode()
        session.switchMode()
        XCTAssertEqual(session.question.step, .frequency)
        XCTAssertEqual(session.draft.frequencyIndex, 11)
        session.advance()
        session.draft.hours = 2
        session.draft.minutes = 45
        session.draft.answeredSteps.insert(.duration)
        session.switchMode()
        session.switchMode()
        XCTAssertEqual(session.question.step, .duration)
        XCTAssertEqual(session.draft.hours, 2)
        XCTAssertEqual(session.draft.minutes, 45)
        XCTAssertTrue(session.draft.canContinue(.duration))
    }

    func testOtherExplanationIsConditionalAndNumericQuestionsCannotBeSkipped() {
        var session = bowelSession()
        XCTAssertEqual(session.question.step, .discomfort)
        session.skip()
        XCTAssertEqual(session.question.step, .discomfort)
        session.previous()
        session.draft.symptoms.insert(.other)
        session.advance()
        XCTAssertEqual(session.question.step, .other)
        session.skip()
        XCTAssertEqual(session.question.step, .discomfort)
    }

    func testEachSelectedSymptomKeepsItsOwnAnswersAndSummary() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.fatigue, .bowel]
        session.advance()
        XCTAssertEqual(session.question.symptom, .fatigue)
        answerDetails(&session, discomfort: 3, count: 1, hours: 2)
        XCTAssertEqual(session.question.symptom, .bowel)
        XCTAssertFalse(session.draft.answeredSteps.contains(.frequency))
        answerDetails(&session, discomfort: 8, count: 11, hours: 0)
        XCTAssertEqual(session.stage, .loading)
        XCTAssertEqual(session.summaryItems.map(\.title), ["피로 및 무기력", "설사 및 변비"])
        XCTAssertEqual(session.summaryItems.map(\.discomfort), [3, 8])
        XCTAssertTrue(session.summaryItems.first?.detail.contains("1번") == true)
        XCTAssertTrue(session.summaryItems.last?.detail.contains("10+번") == true)
    }

    private func bowelSession() -> CareCallConversationPreviewSession {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.bowel]
        session.advance()
        return session
    }

    private func answerDetails(_ session: inout CareCallConversationPreviewSession,
                               discomfort: Int, count: Int, hours: Int) {
        session.draft.discomfort = discomfort
        session.draft.answeredSteps.insert(.discomfort)
        session.advance()
        session.draft.frequencyIndex = count
        session.draft.answeredSteps.insert(.frequency)
        session.advance()
        session.draft.hours = hours
        session.draft.minutes = 30
        session.draft.answeredSteps.insert(.duration)
        session.advance()
        session.skip()
    }
}
