import Foundation
import Observation

enum HomeDestination: Hashable {
    case symptom(autoStartVoice: Bool)
    case symptomDetail
    case pain
    case painDetail
    case notifications
    case previsitLetters
    case previsitLetter(UUID)
}

enum HomeLoadState { case unavailable, loading, loaded, failed }

struct HomeDoctorMessage: Identifiable {
    let id: UUID
    let body: String
    let createdAt: Date
}

@MainActor @Observable final class HomeScreenState {
    var doctor: HomeDoctorState = .unavailable
    /// 홈 인사말과 진료 전 기록 편지의 'From.'에 쓰는 내 이름
    var patientName: String?
    var showsUnreadBadge = false

    var greetingText: String { HomeGreeting.text(for: patientName) }

    var doctorName: String? {
        guard case .linked(let identity) = doctor.connection else { return nil }
        return identity.name
    }
    var isLoading: Bool { doctor.isLoading }
    var doctorTitle: String {
        if let doctorName { return "Dr. \(doctorName)" }
        if case .loaded(.unlinked) = doctor { return "연결된 의료진 없음" }
        return isLoading ? "확인 중" : "의료진 정보 확인 필요"
    }
    var statusMessage: String? {
        switch doctor {
        case .unavailable: "환자·의료진 정보를 확인한 후 보여드려요."
        case .idle: "의료진 정보를 확인해 주세요."
        case .loading: "의료진 정보를 불러오는 중"
        case .loaded: nil
        case .failed(let issue, let previous):
            previous == nil ? issue.message : "최근 의료진 정보예요. 새 정보를 불러오지 못했어요."
        }
    }
}
