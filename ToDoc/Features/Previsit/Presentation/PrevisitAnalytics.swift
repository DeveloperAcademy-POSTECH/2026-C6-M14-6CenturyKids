import Foundation

/// 초안과 함께 유지되는 작성 시도별 계측 상태입니다.
struct PrevisitAnalytics {
    typealias Track = @MainActor (String, [String: Any]) -> Void

    struct Attempt {
        let id = UUID()
        var isPresented = false
        var recordOptionIDs: [String: UUID] = [:]
        var previousCompletedMessage: String?
        var moodVisitID: UUID?
        var moodChangeCount = 0
        var activeDuration: Duration = .zero
    }

    let track: Track?
    private(set) var attempt: Attempt?

    init(track: Track? = nil) {
        self.track = track
    }

    @MainActor
    mutating func screenAppeared(step: PrevisitStep) {
        guard track != nil, attempt?.isPresented != true else { return }
        let isNew = attempt == nil
        if isNew { attempt = Attempt() }
        attempt?.isPresented = true
        emit(isNew ? "previsit_flow_started" : "previsit_flow_resumed", step: step)
    }

    mutating func screenDisappeared() {
        attempt?.isPresented = false
    }

    @MainActor
    mutating func recordSelectionChanged(from previousID: String?, to selectedID: String) {
        guard previousID != selectedID, var attempt else { return }
        let existingID = attempt.recordOptionIDs[selectedID]
        let optionID = existingID ?? UUID()
        let action = existingID != nil ? "reselect" : (attempt.recordOptionIDs.isEmpty ? "initial" : "change")
        attempt.recordOptionIDs[selectedID] = optionID
        self.attempt = attempt
        emit("previsit_record_selection_changed", step: .day, properties: [
            "record_option_id": optionID.uuidString,
            "selection_action": action
        ])
    }

    @MainActor
    mutating func recordStepAdvance(from: PrevisitStep, to: PrevisitStep, message: String) {
        switch (from, to) {
        case (.day, .letter):
            emit("previsit_records_step_completed", step: from)
        case (.letter, .mood):
            guard let attempt else { return }
            var properties: [String: Any] = [
                "has_message": !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ]
            if let previous = attempt.previousCompletedMessage {
                properties["message_changed_since_previous_completion"] = previous != message
            }
            self.attempt?.previousCompletedMessage = message
            emit("previsit_message_step_completed", step: from, properties: properties)
        default:
            break
        }
    }

    @MainActor
    func recordStepBack(from: PrevisitStep, to: PrevisitStep) {
        guard from != to else { return }
        emit("previsit_step_back", step: from, properties: [
            "from_step": stepName(from),
            "to_step": stepName(to)
        ])
    }

    @MainActor
    func emit(_ event: String, step: PrevisitStep, properties: [String: Any] = [:]) {
        guard let attempt, let track else { return }
        var properties = properties
        properties["attempt_id"] = attempt.id.uuidString
        properties["step"] = stepName(step)
        track(event, properties)
    }

    private func stepName(_ step: PrevisitStep) -> String {
        switch step {
        case .day: "record_selection"
        case .letter: "message"
        case .mood: "mood"
        }
    }

    mutating func resetAttempt() {
        attempt = nil
    }
}
