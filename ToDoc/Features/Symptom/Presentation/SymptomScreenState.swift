import Foundation
import Observation

/// 엔진 질문에 대한 입력 그대로입니다. 해석·검증은 호수의 새 ViewModel 담당입니다.
enum SymptomConversationAnswer: Equatable {
    case text(String), severity(Double), frequency(Frequency), durationMinutes(Int)
}
struct SymptomEntryDisplay: Identifiable {
    let id: UUID
    let symptomType: SymptomType
    var bodyPart: BodyPart?
    var bodySide: BodySide?
    var rawLocationText: String?
    var durationMinutes: Int?
    var occurrenceCount: Int?
    var severity: Double?
    var detail: String?
}
struct SymptomRecordDisplay: Identifiable {
    let id: UUID
    let recordedDate: Date
    var symptoms: [SymptomEntryDisplay]
}
/// 숫자 입력을 문자열 그대로 보냅니다. 실패한 변환을 0/nil로 덮어쓰지 않습니다.
struct SymptomEntryEditInput {
    var durationText: String
    var occurrenceText: String
    var severity: Double?
    var detail: String
    init(_ entry: SymptomEntryDisplay) {
        durationText = entry.durationMinutes.map(String.init) ?? ""
        occurrenceText = entry.occurrenceCount.map(String.init) ?? ""
        severity = entry.severity; detail = entry.detail ?? ""
    }
}
enum CareCallAction { case prepare, cancel }
@Observable final class CareCallScreenState {
    var preparation: CareCallPreparationState = .unavailable
    var canStart = false
    var isPreparing = false
    @ObservationIgnored var onAction: ((CareCallAction) -> Void)?
}
enum SymptomAction {
    case start, listen, previous, cancel
    case answer(SymptomConversationAnswer)
    case switchMode(SymptomConversationMode)
}
@Observable final class SymptomScreenState {
    var question: SymptomConversationQuestion?
    var mode: SymptomConversationMode = .text
    var answerText = ""
    var transcript = ""
    var isWorking = false
    var isListening = false
    var isSummarizing = false
    var hasCompletedVoiceInput = false
    var canGoPrevious = false
    var restoredAnswer: SymptomConversationAnswer?
    var errorMessage: String?
    var summary: SymptomSummaryScreenState?
    var didSave = false
    @ObservationIgnored var onAction: ((SymptomAction) -> Void)?
}
enum SymptomSummaryAction {
    case edit(UUID), delete(UUID), finishEdit(UUID, SymptomEntryEditInput), discardEdit, save, cancel
}
@Observable final class SymptomSummaryScreenState {
    var record: SymptomRecordDisplay
    var editingEntryID: UUID?
    var isSaving = false
    var canSave = false
    var errorMessage: String?
    var editErrorMessage: String?
    @ObservationIgnored var onAction: ((SymptomSummaryAction) -> Void)?
    init(record: SymptomRecordDisplay) { self.record = record }
}
