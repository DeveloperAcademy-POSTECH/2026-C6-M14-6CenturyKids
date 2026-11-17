import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 저장된 하루 기록의 표시 값과 원본 식별자입니다. 전송 계약은 별도입니다.
struct PrevisitDay: Identifiable, Hashable {
    struct PainRow: Hashable {
        let location: String
        let before: Int
        let after: Int?

        var entry: String { "\(location) 통증 \(before) → \(after.map { String($0) } ?? "사후 통증 미기록")" }
    }

    struct SymptomRow: Hashable {
        let label: String
        let detail: String?
        let entry: String
    }

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
    var painRows: [PainRow] = []
    var symptomRows: [SymptomRow] = []
    var representativePain: PainRow? = nil

    var isSelectable: Bool { !entries.isEmpty }

    var displayDate: String {
        guard let recordedDate else { return dateLabel }
        let components = Calendar.current.dateComponents([.month, .day], from: recordedDate)
        guard let month = components.month, let day = components.day else { return dateLabel }
        return "\(month)월 \(day)일"
    }

    var displayWeekday: String {
        guard let recordedDate else { return weekday }
        return recordedDate.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "ko_KR")))
    }
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
