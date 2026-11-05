import Foundation

@MainActor
struct SymptomConversationAnalytics {
    typealias Track = (String, [String: Any]) -> Void

    enum Step: String, Equatable {
        case conversation
        case summaryLoading = "summary_loading"
    }

    enum Screen: Equatable {
        case visible(Step, SymptomConversationMode)
        case hidden
        case paused
        case backgrounded
        case completed
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

    private let track: Track?
    private let clock = ContinuousClock()
    private var attempt: Attempt?
    private var interval: ActiveInterval?

    init(track: Track? = nil) {
        self.track = track
    }

    mutating func updateScreen(_ screen: Screen) {
        guard let track else { return }

        guard case let .visible(step, mode) = screen else {
            let reason: String = switch screen {
            case .paused: "paused"
            case .backgrounded: "backgrounded"
            case .completed: "completed"
            case .hidden, .visible: "step_changed"
            }
            finishInterval(reason: reason)
            return
        }

        if interval?.step == step, interval?.mode == mode { return }
        finishInterval(reason: "step_changed")

        if attempt == nil, step == .conversation {
            let newAttempt = Attempt(initialMode: mode)
            attempt = newAttempt
            track("symptom_conversation_started", properties(for: newAttempt, step: step, mode: mode))
        }
        guard attempt != nil else { return }
        interval = ActiveInterval(step: step, mode: mode, startedAt: clock.now)
    }

    mutating func finishInterval(reason: String) {
        guard let attempt, let interval, let track else { return }
        self.interval = nil

        let elapsed = interval.startedAt.duration(to: clock.now).components
        let milliseconds = elapsed.seconds * 1_000 + elapsed.attoseconds / 1_000_000_000_000_000
        var properties = properties(for: attempt, step: interval.step, mode: interval.mode)
        properties["active_duration_ms"] = milliseconds
        properties["engagement_end_reason"] = reason
        track("symptom_step_engagement", properties)
    }

    private func properties(for attempt: Attempt, step: Step, mode: SymptomConversationMode) -> [String: Any] {
        [
            "attempt_id": attempt.id.uuidString,
            "initial_mode": attempt.initialMode == .voice ? "voice" : "text",
            "current_mode": mode == .voice ? "voice" : "text",
            "step": step.rawValue
        ]
    }
}
