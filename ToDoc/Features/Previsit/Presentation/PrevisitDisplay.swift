import Foundation

/// 화면 표시/입력 계약. 실제 기록 조회·전송은 추후 연결합니다.
struct PrevisitDay: Identifiable, Hashable {
    let id: String
    let dateLabel: String
    let weekday: String
    let entries: [String]
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
struct PrevisitDraft {
    var day: PrevisitDay?
    var letter = ""
    var mood: PrevisitMood?
}
enum PrevisitStep { case day, letter, mood }
