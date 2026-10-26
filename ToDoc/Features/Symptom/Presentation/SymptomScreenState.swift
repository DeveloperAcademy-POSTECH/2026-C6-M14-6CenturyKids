#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 엔진 질문에 대한 입력 그대로입니다. 해석·검증은 호수의 새 ViewModel 담당입니다.
enum SymptomConversationAnswer: Equatable {
    case text(String), frequency(Frequency), durationMinutes(Int)
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

    /// 요약·상세는 있음만 표시합니다. 저장용 symptoms에는 없음·모름도 보존합니다.
    var presentSymptoms: [SymptomEntryDisplay] {
        symptoms.filter { $0.presence == .present }
    }
}
/// 숫자 입력을 문자열 그대로 보냅니다. 실패한 변환을 0/nil로 덮어쓰지 않습니다.
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
    /// open: 화면에 들어옴 (음성은 첫 질문만 보여 주고 "대화 시작하기"를 기다린다). start: 지금 방식으로 대화를 시작하거나 잇는다
    case open, start, previous, cancel
    case answer(SymptomConversationAnswer)
    case switchMode(SymptomConversationMode)
    /// 기록 중단 팝업: 띄우면 통화를 잠시 멈추고, 계속 작성하면 잇고, 그만하면 저장하지 않은 기록을 버린다
    case pause, resume, discard
}
@Observable final class SymptomScreenState {
    // 음성 통화는 자동 진행합니다. ViewModel이 AI 발화·듣기·전사 상태를 전달합니다.
    // 문자 답변의 문장 변환과 같은 엔진 호출도 ViewModel 담당입니다.
    var question: SymptomConversationQuestion?
    var mode: SymptomConversationMode = .text
    var answerText = ""
    var transcript = ""
    var isWorking = false
    var isListening = false
    /// 음성 통화를 거는 중이거나 통화 중 (음성 화면 아래 버튼이 "음성 인식 중 ..")
    var isCalling = false
    var isSummarizing = false
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
