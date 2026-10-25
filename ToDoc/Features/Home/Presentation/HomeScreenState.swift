import Foundation
import Observation

enum HomeDestination: Hashable {
    case symptom(autoStartVoice: Bool)
    case pain
    case notifications
}

enum HomeLoadState { case unavailable, loading, loaded, failed }

struct HomeDoctorMessage: Identifiable {
    let id: UUID
    let body: String
    let createdAt: Date
}

@Observable final class HomeScreenState {
    var doctorName: String?
    var message: HomeDoctorMessage?
    var showsUnreadBadge = false
    var loadState: HomeLoadState = .unavailable
    var isLoading = false
    @ObservationIgnored var onReload: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
