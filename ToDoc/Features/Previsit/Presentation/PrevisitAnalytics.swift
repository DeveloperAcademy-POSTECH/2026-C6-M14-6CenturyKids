import Foundation

/// 초안과 함께 유지되는 작성 시도별 계측 상태입니다.
struct PrevisitAnalytics {
    typealias Track = @MainActor (String, [String: Any]) -> Void

    struct Attempt {
        let id = UUID()
        var isPresented = false
        var recordOptionIDs: [String: UUID] = [:]
        var previousCompletedMessage: String?
        var visibleStep: PrevisitStep?
        var activeSince: ContinuousClock.Instant?
        var moodVisitID: UUID?
        var didSelectMood = false
        var activeTimeBeforeFirstMoodSelection: Duration = .zero
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

    @MainActor
    mutating func screenDisappeared() {
        endActiveInterval(reason: "closed")
        attempt?.isPresented = false
        attempt?.visibleStep = nil
    }

    @MainActor
    mutating func updateVisibleStep(
        _ step: PrevisitStep, hasMoodSelection: Bool, pausedBy reason: String?,
        now: ContinuousClock.Instant = .now
    ) {
        guard attempt?.isPresented == true else { return }
        if attempt?.visibleStep != step {
            endActiveInterval(reason: "step_changed", now: now)
            attempt?.visibleStep = step
            if step == .mood {
                let visitID = UUID()
                attempt?.moodVisitID = visitID
                emit("previsit_mood_step_viewed", step: step, properties: [
                    "step_visit_id": visitID.uuidString,
                    "has_mood_selection": hasMoodSelection
                ])
            } else {
                attempt?.moodVisitID = nil
            }
        }
        if let reason {
            endActiveInterval(reason: reason, now: now)
        } else if attempt?.activeSince == nil {
            attempt?.activeSince = now
        }
    }

    @MainActor
    mutating func recordMoodSelection(replacingSelection: Bool, now: ContinuousClock.Instant = .now) {
        guard let attempt, attempt.visibleStep == .mood, let visitID = attempt.moodVisitID else { return }
        if !attempt.didSelectMood, !replacingSelection {
            let currentInterval = attempt.activeSince.map { $0.duration(to: now) } ?? .zero
            let duration = attempt.activeTimeBeforeFirstMoodSelection + currentInterval
            self.attempt?.didSelectMood = true
            emit("previsit_mood_selected", step: .mood, properties: [
                "step_visit_id": visitID.uuidString,
                "active_ms_to_first_mood_selection": milliseconds(duration)
            ])
        } else if replacingSelection {
            self.attempt?.didSelectMood = true
            let count = attempt.moodChangeCount + 1
            self.attempt?.moodChangeCount = count
            emit("previsit_mood_changed", step: .mood, properties: [
                "step_visit_id": visitID.uuidString,
                "mood_change_count": count
            ])
        }
    }

    @MainActor
    mutating func endActiveInterval(reason: String, now: ContinuousClock.Instant = .now) {
        guard let attempt, let step = attempt.visibleStep, let start = attempt.activeSince else { return }
        let duration = start.duration(to: now)
        self.attempt?.activeSince = nil
        self.attempt?.activeDuration += duration
        if step == .mood, !attempt.didSelectMood {
            self.attempt?.activeTimeBeforeFirstMoodSelection += duration
        }
        var properties: [String: Any] = [
            "active_duration_ms": milliseconds(duration),
            "engagement_end_reason": reason
        ]
        if step == .mood { properties["step_visit_id"] = attempt.moodVisitID?.uuidString }
        emit("previsit_step_engagement", step: step, properties: properties)
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
    func recordStepBack(from: PrevisitStep, to: PrevisitStep, hasMoodSelection: Bool) {
        guard from != to else { return }
        var properties: [String: Any] = [
            "from_step": stepName(from),
            "to_step": stepName(to)
        ]
        if from == .mood { properties["has_mood_selection"] = hasMoodSelection }
        emit("previsit_step_back", step: from, properties: properties)
    }

    @MainActor
    mutating func recordClose(step: PrevisitStep, hasMoodSelection: Bool) {
        endActiveInterval(reason: "closed")
        guard let attempt else { return }
        var properties: [String: Any] = ["cumulative_active_ms": milliseconds(attempt.activeDuration)]
        if step == .mood { properties["has_mood_selection"] = hasMoodSelection }
        emit("previsit_flow_closed", step: step, properties: properties)
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

    private func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000)
    }

    mutating func resetAttempt() {
        attempt = nil
    }
}
