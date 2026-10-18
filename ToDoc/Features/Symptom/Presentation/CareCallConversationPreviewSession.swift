#if DEBUG
import Foundation

/// UI walkthrough state only. The live CareCallViewModel remains responsible for real interviews.
struct CareCallConversationPreviewSession {
    enum Stage { case incoming, conversation, loading, completed, summary }
    struct Question: Equatable {
        var step: CareCallManualStep
        var symptom: CareCallManualSymptom?
    }
    var stage: Stage = .incoming
    var mode: SymptomConversationMode = .voice
    private var questionIndex = 0
    private var introduction = CareCallManualDraft()
    private var answers: [CareCallManualSymptom: CareCallManualDraft] = [:]
    var isListening = false
    var summaryItems: [CareCallVoiceSummaryItem] = []
    var editingItemID: UUID?

    var question: Question { questions[min(questionIndex, questions.count - 1)] }
    var progress: Double { Double(questionIndex + 1) / Double(max(4, questions.count)) }
    var canGoPrevious: Bool { stage == .conversation && questionIndex > 0 }
    var draft: CareCallManualDraft {
        get {
            if let symptom = question.symptom { return answers[symptom] ?? CareCallManualDraft() }
            return introduction
        }
        set {
            if let symptom = question.symptom { answers[symptom] = newValue }
            else { introduction = newValue }
        }
    }

    var questionText: String {
        guard let symptom = question.symptom else { return question.step.question }
        let title = symptom.title.replacingOccurrences(of: "\n", with: " ")
        switch question.step {
        case .frequency: return "\(title) 증상을 몇 번 겪으셨나요?"
        case .duration: return "\(title) 증상이 얼마나 지속 되었나요?"
        case .dailyLife: return "\(title) 때문에 일상 생활에 어떤 지장이 있었나요?"
        default: return question.step.question
        }
    }

    /// A deterministic UI walkthrough, not a clinical interview policy.
    /// The real engine decides which follow-up questions are appropriate after integration.
    private var questions: [Question] {
        var result = [Question(step: .symptoms)]
        if introduction.symptoms.contains(.other) { result.append(Question(step: .other)) }
        for symptom in selectedSymptoms {
            for step: CareCallManualStep in [.frequency, .duration, .dailyLife] {
                result.append(Question(step: step, symptom: symptom))
            }
        }
        return result
    }
    private var selectedSymptoms: [CareCallManualSymptom] {
        CareCallManualSymptom.allCases.filter { introduction.symptoms.contains($0) }
    }

    mutating func enter(_ mode: SymptomConversationMode) {
        self.mode = mode
        stage = .conversation
    }
    mutating func switchMode() {
        if stage == .incoming { enter(.text); return }
        guard stage == .conversation else { return }
        mode = mode == .voice ? .text : .voice
    }
    mutating func advance() {
        guard stage == .conversation, draft.canContinue(question.step) else { return }
        moveForward()
    }
    mutating func skip() {
        guard stage == .conversation, question.step.allowsSkipping else { return }
        // Skipping doesn't submit a partially typed answer.
        var value = draft
        if question.step == .other { value.other = "" } else { value.dailyLife = "" }
        value.answeredSteps.remove(question.step)
        draft = value
        moveForward()
    }
    mutating func previous() {
        guard canGoPrevious else { return }
        questionIndex -= 1
    }
    private mutating func moveForward() {
        if questionIndex + 1 < questions.count {
            questionIndex += 1
        } else {
            summaryItems = selectedSymptoms.compactMap { symptom in
                guard let value = answers[symptom] else { return nil }
                let count = value.frequencyIndex == 11 ? "10+" : String(value.frequencyIndex)
                var details: [String] = []
                if symptom == .other, !introduction.other.isEmpty { details.append(introduction.other) }
                if !value.dailyLife.isEmpty { details.append(value.dailyLife) }
                return CareCallVoiceSummaryItem(id: UUID(),
                    title: symptom.title.replacingOccurrences(of: "\n", with: " "),
                    detailLabel: "말씀하신 내용", detail: details.joined(separator: "\n\n"),
                    frequency: value.answeredSteps.contains(.frequency) ? "\(count)번" : nil,
                    duration: value.answeredSteps.contains(.duration) ? "\(value.hours)시간 \(value.minutes)분" : nil)
            }
            stage = .loading
        }
    }

    /// Explicit development control; never runs automatically or opens the microphone.
    mutating func useSampleVoiceAnswer() {
        guard stage == .conversation, mode == .voice else { return }
        var value = draft
        switch question.step {
        case .symptoms:
            if value.symptoms.isEmpty { value.symptoms = [.bowel] }
        case .other:
            if value.other.isEmpty { value.other = "관절이 아파요" }
        case .dailyLife:
            if value.dailyLife.isEmpty { value.dailyLife = "밥 먹기가 두려워요" }
        case .frequency, .duration: break
        }
        value.answeredSteps.insert(question.step)
        draft = value
        isListening = true
        advance()
    }
}
#endif
