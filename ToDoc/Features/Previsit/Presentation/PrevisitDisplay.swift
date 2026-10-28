import Foundation

/// 저장된 하루 기록의 표시 값과 원본 식별자입니다. 전송 계약은 별도입니다.
struct PrevisitDay: Identifiable, Hashable {
    let id: String
    let dateLabel: String
    let weekday: String
    let entries: [String]
    var recordedDate: Date? = nil
    var painRecordIDs: [UUID] = []
    var symptomRecordIDs: [UUID] = []
    /// 목록 배지의 통증 점수: 그날 복용 전·후가 다 있는 마지막 기록, 없으면 마지막 기록 (복용 후는 nil)
    var painBefore: Int? = nil
    var painAfter: Int? = nil
    /// 그날 '있음'으로 답한 증상 수 (목록 배지)
    var symptomCount = 0

    var isSelectable: Bool { !entries.isEmpty }
}

enum PrevisitRecordState: Equatable {
    case loading, loaded([PrevisitDay]), failed
}
enum PrevisitMood: String, CaseIterable, Identifiable {
    case candid, comfortable, slowly, carefully, unsure
    var id: String { rawValue }
    var caption: String? {
        switch self {
        case .candid: "차분히 이야기를 들을 수 있어요"
        case .comfortable: "걱정되지만 이야기를 듣고싶어요"
        case .slowly: "걱정되는 마음이 커요"
        case .carefully: "마음의 준비가 더 필요해요"
        case .unsure: nil
        }
    }
    var title: String {
        switch self {
        case .candid: "숨김없이 이야기 해주세요"
        case .comfortable: "편하게 이야기 해주세요"
        case .slowly: "천천히 이야기 해주세요"
        case .carefully: "조심스럽게 이야기 해주세요"
        case .unsure: "아직 잘 모르겠어요"
        }
    }
}
struct PrevisitDraft: Equatable {
    var day: PrevisitDay?
    var letter = ""
    var mood: PrevisitMood?
}
enum PrevisitStep: Equatable { case day, letter, mood }
/// 보낸 진료 전 기록 한 건. 날짜는 고른 기록의 날이 아니라 작성(전송)한 날입니다.
struct PrevisitLetter: Identifiable, Equatable {
    let id: UUID
    let sentAt: Date
    /// 보낸 때의 주치의 이름 ("To. 학로쌤")
    let doctorName: String
    var draft: PrevisitDraft
}
