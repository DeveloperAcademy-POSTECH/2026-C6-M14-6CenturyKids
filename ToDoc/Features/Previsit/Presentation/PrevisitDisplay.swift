import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 저장된 하루 기록의 표시 값과 원본 식별자입니다. 전송 계약은 별도입니다.
struct PrevisitDay: Identifiable, Hashable {
    let id: String
    let dateLabel: String
    let weekday: String
    let entries: [String]
    var recordedDate: Date? = nil
    var painRecordIDs: [UUID] = []
    var symptomRecordIDs: [UUID] = []
    /// 목록 배지의 통증 점수: 그날 악화 후 통증이 가장 높은 기록 또는 감소 폭이 가장 작은 기록. 전후 기록이 없으면 복용 전 통증이 가장 높은 기록
    var painBefore: Int? = nil
    var painAfter: Int? = nil
    /// 그날 '있음'으로 답한 증상 수 (목록 배지)
    var symptomCount = 0

    var isSelectable: Bool { !entries.isEmpty }
}

enum PrevisitRecordState: Equatable {
    case loading, loaded([PrevisitDay]), failed
}
struct PrevisitDraft: Equatable {
    var day: PrevisitDay?
    var letter = ""
    var mood: StateOfMind?
}
enum PrevisitStep: Equatable { case day, letter, mood }
/// 보낸 진료 전 기록 한 건. 날짜는 고른 기록의 날이 아니라 작성(전송)한 날입니다.
struct PrevisitLetter: Identifiable, Equatable {
    let id: UUID
    let sentAt: Date
    /// 화면에 표시할 주치의 이름 (저장소에는 의사 이름을 보관하지 않습니다)
    let doctorName: String
    var draft: PrevisitDraft
}
