#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

enum SymptomConversationAnswer: Equatable {
    case text(String), frequency(Frequency)
}
struct SymptomEntryDisplay: Identifiable {
    let id: UUID
    let symptomType: SymptomType
    let presence: SymptomPresence
    var bodyPart: BodyPart?
    var bodySide: BodySide?
    var rawLocationText: String?
    var durationMinutes: Int?
    var occurrenceCount: Int?
    var detail: String?
}
struct SymptomRecordDisplay: Identifiable {
    let id: UUID
    let recordedDate: Date
    var symptoms: [SymptomEntryDisplay]

    var presentSymptoms: [SymptomEntryDisplay] {
        symptoms.filter { $0.presence == .present }
    }
}
struct SymptomEntryEditInput {
    var durationText: String
    var occurrenceText: String
    var detail: String
    init(_ entry: SymptomEntryDisplay) {
        durationText = entry.durationMinutes.map(String.init) ?? ""
        occurrenceText = entry.occurrenceCount.map(String.init) ?? ""
        detail = entry.detail ?? ""
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
    case open, start, previous, cancel
    case answer(SymptomConversationAnswer)
    case switchMode(SymptomConversationMode)
    case pause, resume, discard
    case stopForEmergency, continueAfterEmergency
}
@Observable final class SymptomScreenState {
    var question: SymptomConversationQuestion?
    var mode: SymptomConversationMode = .text
    var answerText = ""
    var transcript = ""
    var isWorking = false
    var voiceState: SymptomVoiceState = .thinking
    var isCalling = false
    var isSummarizing = false
    var canGoPrevious = false
    var restoredAnswer: SymptomConversationAnswer?
    var errorMessage: String?
    var needsMicrophone = false
    var isEmergency = false
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
