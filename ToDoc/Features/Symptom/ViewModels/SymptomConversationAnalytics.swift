import Foundation

@MainActor
struct SymptomConversationAnalytics {
    typealias Track = (String, [String: Any]) -> Void

    enum Step: String, Equatable {
        case conversation
        case summaryLoading = "summary_loading"
    }

    enum Screen: Equatable {
        case visible(Step, SymptomConversationMode, QuestionPresentation? = nil, readyModeChangeID: UUID? = nil, canResume: Bool = false)
        case hidden
        case paused
        case backgrounded
        case completed
    }

    struct QuestionPresentation: Equatable {
        enum Navigation: Equatable {
            case previousButton, nextButton, nextAutomatic
        }

        let revision = UUID()
        let id: UUID
        let navigation: Navigation?
    }

    private struct Attempt {
        let id = UUID()
        let initialMode: SymptomConversationMode
    }

    private struct ActiveInterval {
        let step: Step
        let mode: SymptomConversationMode
        let startedAt: ContinuousClock.Instant
    }

    private struct ModeChange {
        let id = UUID()
        let from: SymptomConversationMode
        let to: SymptomConversationMode
        let questionID: UUID
        let answerRevisions: Set<UUID>?
    }

    private let track: Track?
    private let clock = ContinuousClock()
    private var attempt: Attempt?
    private var interval: ActiveInterval?
    private var lastQuestion: QuestionPresentation?
    private var presentedQuestions: Set<UUID> = []
    private var answeredQuestions: Set<UUID> = []
    private var pendingModeChange: ModeChange?
    private var isConversationPaused = false
    private var cumulativeActiveMilliseconds: Int64 = 0

    init(track: Track? = nil) {
        self.track = track
    }

    mutating func updateScreen(_ screen: Screen) {
        guard let track else { return }

        guard case let .visible(step, mode, question, _, canResume) = screen else {
            let reason: String = switch screen {
            case .paused: "paused"
            case .backgrounded: "backgrounded"
            case .completed: "completed"
            case .hidden, .visible: "step_changed"
            }
            finishInterval(reason: reason)
            return
        }

        if attempt == nil, step == .conversation {
            let newAttempt = Attempt(initialMode: mode)
            attempt = newAttempt
            track("symptom_conversation_started", properties(for: newAttempt, step: step, mode: mode))
        }
        guard let attempt else { return }
        if interval?.step != step || interval?.mode != mode {
            finishInterval(reason: "step_changed")
            interval = ActiveInterval(step: step, mode: mode, startedAt: clock.now)
        }
        if let question { present(question, for: attempt, mode: mode, track: track) }
        if canResume, isConversationPaused {
            isConversationPaused = false
            track("symptom_conversation_resumed", progressProperties(for: attempt, mode: mode))
        }
    }

    private mutating func present(_ question: QuestionPresentation, for attempt: Attempt, mode: SymptomConversationMode, track: Track) {
        guard question.revision != lastQuestion?.revision else { return }
        let previous = lastQuestion
        lastQuestion = question
        var properties = properties(for: attempt, step: .conversation, mode: mode)
        properties["current_question_id"] = question.id.uuidString

        if let previous, previous.id != question.id, let navigation = question.navigation {
            var movement = properties
            movement["from_question_id"] = previous.id.uuidString
            movement["to_question_id"] = question.id.uuidString
            movement["direction"] = navigation == .previousButton ? "previous" : "next"
            movement["navigation_trigger"] = navigation == .nextAutomatic ? "automatic" : "button"
            track("symptom_question_moved", movement)
        }

        properties["question_id"] = question.id.uuidString
        properties["is_first_presentation"] = presentedQuestions.insert(question.id).inserted
        properties["question_count"] = presentedQuestions.count
        properties["answered_question_count"] = answeredQuestions.count
        track("symptom_question_presented", properties)
    }

    mutating func answerCompleted(_ completion: CareCallAnswerCompletion, mode: SymptomConversationMode) {
        guard let track, let attempt, presentedQuestions.contains(completion.questionID) else { return }
        answeredQuestions.insert(completion.questionID)
        var properties = properties(for: attempt, step: .conversation, mode: mode)
        properties["current_question_id"] = completion.questionID.uuidString
        properties["question_id"] = completion.questionID.uuidString
        properties["answer_action"] = completion.action.rawValue
        properties["answered_question_count"] = answeredQuestions.count
        track("symptom_answer_completed", properties)
    }

    mutating func requestModeChange(
        from: SymptomConversationMode, to: SymptomConversationMode, questionID: UUID, answerRevisions: Set<UUID>?
    ) {
        guard let track, let attempt else { return }
        let change = ModeChange(from: from, to: to, questionID: questionID, answerRevisions: answerRevisions)
        pendingModeChange = change
        track("symptom_mode_change_requested", modeChangeProperties(for: attempt, change: change, mode: from, questionID: questionID))
    }

    func pendingModeChangeID(for mode: SymptomConversationMode) -> UUID? {
        guard let pendingModeChange, pendingModeChange.to == mode else { return nil }
        return pendingModeChange.id
    }

    mutating func cancelModeChange() {
        pendingModeChange = nil
    }

    mutating func pauseConversation(mode: SymptomConversationMode) {
        guard let track, let attempt, !isConversationPaused else { return }
        finishInterval(reason: "paused")
        isConversationPaused = true
        var properties = progressProperties(for: attempt, mode: mode)
        properties["pause_reason"] = "pause_action"
        properties["cumulative_active_ms"] = cumulativeActiveMilliseconds
        track("symptom_conversation_paused", properties)
    }

    mutating func discardConversation(mode: SymptomConversationMode) {
        guard let track, let attempt, isConversationPaused else { return }
        finishInterval(reason: "discarded")
        isConversationPaused = false
        var properties = progressProperties(for: attempt, mode: mode)
        properties["cumulative_active_ms"] = cumulativeActiveMilliseconds
        track("symptom_conversation_discarded", properties)
    }

    private func progressProperties(for attempt: Attempt, mode: SymptomConversationMode) -> [String: Any] {
        var properties = properties(for: attempt, step: .conversation, mode: mode)
        properties["question_count"] = presentedQuestions.count
        properties["answered_question_count"] = answeredQuestions.count
        properties["current_question_id"] = lastQuestion?.id.uuidString
        return properties
    }

    mutating func completeModeChange(id: UUID, mode: SymptomConversationMode, questionID: UUID, answerRevisions: Set<UUID>?) {
        guard let track, let attempt, let change = pendingModeChange, change.id == id, change.to == mode else { return }
        pendingModeChange = nil
        var properties = modeChangeProperties(for: attempt, change: change, mode: mode, questionID: questionID)
        properties["question_preserved"] = change.questionID == questionID
        if let before = change.answerRevisions, let answerRevisions {
            properties["answers_preserved"] = before.isSubset(of: answerRevisions)
        }
        track("symptom_mode_changed", properties)
    }

    private func modeChangeProperties(
        for attempt: Attempt, change: ModeChange, mode: SymptomConversationMode, questionID: UUID
    ) -> [String: Any] {
        var properties = properties(for: attempt, step: .conversation, mode: mode)
        properties["mode_change_id"] = change.id.uuidString
        properties["from_mode"] = modeName(change.from)
        properties["to_mode"] = modeName(change.to)
        properties["current_question_id"] = questionID.uuidString
        return properties
    }

    mutating func finishInterval(reason: String) {
        guard let attempt, let interval, let track else { return }
        self.interval = nil

        let elapsed = interval.startedAt.duration(to: clock.now).components
        let milliseconds = elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000
        cumulativeActiveMilliseconds += milliseconds
        var properties = properties(for: attempt, step: interval.step, mode: interval.mode)
        properties["active_duration_ms"] = milliseconds
        properties["engagement_end_reason"] = reason
        track("symptom_step_engagement", properties)
    }

    private func properties(for attempt: Attempt, step: Step, mode: SymptomConversationMode) -> [String: Any] {
        [
            "attempt_id": attempt.id.uuidString,
            "initial_mode": modeName(attempt.initialMode),
            "current_mode": modeName(mode),
            "step": step.rawValue
        ]
    }

    private func modeName(_ mode: SymptomConversationMode) -> String {
        mode == .voice ? "voice" : "text"
    }
}
