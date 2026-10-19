import XCTest
@testable import ToDocCareCall

final class CareCallConversationPreviewTests: XCTestCase {
    func testChatEntryStartsAtSymptomSelection() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        XCTAssertEqual(session.stage, .conversation)
        XCTAssertEqual(session.mode, .text)
        XCTAssertEqual(session.question.step, .symptoms)
        XCTAssertLessThan(session.progress, 1)
    }

    func testManualPathReachesSummaryWithoutRatingQuestion() {
        var session = bowelSession()
        XCTAssertEqual(session.question.step, .frequency)
        session.advance()
        XCTAssertEqual(session.question.step, .frequency, "A visible default is not an answer.")
        session.draft.frequencyIndex = 0
        session.draft.answeredSteps.insert(.frequency)
        session.advance()
        XCTAssertEqual(session.question.step, .duration)
        session.draft.hours = 0
        session.draft.minutes = 5
        session.draft.answeredSteps.insert(.duration)
        session.advance()
        XCTAssertEqual(session.question.step, .dailyLife)
        XCTAssertEqual(session.progress, 1)
        session.skip()
        XCTAssertEqual(session.stage, .loading)
        XCTAssertEqual(session.summaryItems.count, 1)
        XCTAssertEqual(session.summaryItems.first?.frequency, "0번")
        XCTAssertEqual(session.summaryItems.first?.duration, "0시간 5분")
        XCTAssertEqual(session.summaryItems.first?.detail, "", "Skipping must not invent patient words.")
    }

    func testModeRoundTripKeepsQuestionAndTypedDraft() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.bowel, .other]
        session.advance()
        XCTAssertEqual(session.question.step, .other)
        session.draft.other = "관절이 아파요\n아침부터 그랬어요."
        session.draft.answeredSteps.insert(.other)
        let question = session.question
        session.switchMode()
        XCTAssertEqual(session.mode, .voice)
        XCTAssertEqual(session.question, question)
        session.switchMode()
        XCTAssertEqual(session.mode, .text)
        XCTAssertEqual(session.draft.other, "관절이 아파요\n아침부터 그랬어요.")
        XCTAssertTrue(session.draft.canContinue(.other))
    }

    func testModeRoundTripKeepsCountAndDurationSelection() {
        var session = bowelSession()
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
        XCTAssertEqual(session.question.step, .frequency)
        session.skip()
        XCTAssertEqual(session.question.step, .frequency)
        session.previous()
        session.draft.symptoms.insert(.other)
        session.advance()
        XCTAssertEqual(session.question.step, .other)
        session.skip()
        XCTAssertEqual(session.question.step, .frequency)
    }

    func testEachSelectedSymptomKeepsItsOwnWords() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.fatigue, .bowel]
        session.advance()
        XCTAssertEqual(session.question.symptom, .fatigue)
        answerDetails(&session, count: 1, hours: 2, words: "오후 내내 축 처졌어요.\n잠깐 누워 있었어요.")
        XCTAssertEqual(session.question.symptom, .bowel)
        XCTAssertFalse(session.draft.answeredSteps.contains(.frequency))
        answerDetails(&session, count: 11, hours: 0, words: "밥 먹기가 두려워요…")
        XCTAssertEqual(session.stage, .loading)
        XCTAssertEqual(session.summaryItems.map(\.frequency), ["1번", "10+번"])
        XCTAssertEqual(session.summaryItems.map(\.duration), ["2시간 30분", "0시간 30분"])
        XCTAssertEqual(session.summaryItems.map(\.title), ["피로 및 무기력", "설사 및 변비"])
        XCTAssertEqual(session.summaryItems.map(\.detail), ["오후 내내 축 처졌어요.\n잠깐 누워 있었어요.", "밥 먹기가 두려워요…"])
    }

    func testOtherAndDailyLifeWordsKeepWhitespacePunctuationAndLineBreaks() {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.other]
        session.advance()
        session.draft.other = "  관절이 아픈 건지 잘 모르겠어요…\n아침부터 그랬어요.  "
        session.draft.answeredSteps.insert(.other)
        session.advance()
        answerDetails(&session, count: 2, hours: 1, words: "걷다가 쉬었어요.\n‘찌릿’ 했어요.")
        XCTAssertEqual(session.stage, .loading)
        XCTAssertEqual(session.summaryItems.first?.detail,
            "  관절이 아픈 건지 잘 모르겠어요…\n아침부터 그랬어요.  \n\n걷다가 쉬었어요.\n‘찌릿’ 했어요.")
    }

    func testLongPatientAnswerIsNotShortenedInSummary() {
        var session = bowelSession()
        let words = String(repeating: "먹은 뒤 배가 꾸르륵거려서 잠시 쉬었어요.\n", count: 80)
        answerDetails(&session, count: 1, hours: 0, words: words)
        XCTAssertEqual(session.summaryItems.first?.detail, words)
    }

    func testSkippingTypedAnswerDoesNotIncludeItInSummary() {
        var session = bowelSession()
        session.draft.answeredSteps.insert(.frequency)
        session.advance()
        session.draft.answeredSteps.insert(.duration)
        session.advance()
        session.draft.dailyLife = "아직 제출하지 않은 말"
        session.draft.answeredSteps.insert(.dailyLife)
        session.skip()
        XCTAssertEqual(session.summaryItems.first?.detail, "")
    }

    private func bowelSession() -> CareCallConversationPreviewSession {
        var session = CareCallConversationPreviewSession()
        session.enter(.text)
        session.draft.symptoms = [.bowel]
        session.advance()
        return session
    }

    private func answerDetails(_ session: inout CareCallConversationPreviewSession,
                               count: Int, hours: Int, words: String) {
        session.draft.frequencyIndex = count
        session.draft.answeredSteps.insert(.frequency)
        session.advance()
        session.draft.hours = hours
        session.draft.minutes = 30
        session.draft.answeredSteps.insert(.duration)
        session.advance()
        session.draft.dailyLife = words
        session.draft.answeredSteps.insert(.dailyLife)
        session.advance()
    }
}
