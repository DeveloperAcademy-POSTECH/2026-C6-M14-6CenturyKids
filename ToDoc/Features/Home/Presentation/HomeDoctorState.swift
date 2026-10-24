import Foundation

nonisolated struct HomeDoctorIdentity: Equatable, Sendable {
    let id: UUID
    let name: String
}

nonisolated enum HomeDoctorConnection: Equatable, Sendable {
    case unlinked
    case linked(HomeDoctorIdentity)
}

nonisolated enum HomeIssue: Error, Equatable, Sendable {
    case patientUnavailable, patientMismatch, doctorUnavailable, doctorMismatch, loadFailed

    var message: String {
        switch self {
        case .patientUnavailable, .patientMismatch: "환자 정보를 확인하지 못했어요."
        case .doctorUnavailable, .doctorMismatch: "연결된 의료진 정보를 확인하지 못했어요."
        case .loadFailed: "의료진 정보를 불러오지 못했어요."
        }
    }
}

nonisolated enum HomeDoctorState: Equatable, Sendable {
    case unavailable
    case idle
    case loading(previous: HomeDoctorConnection?)
    case loaded(HomeDoctorConnection)
    case failed(HomeIssue, previous: HomeDoctorConnection?)

    var connection: HomeDoctorConnection? {
        switch self {
        case .loading(let previous), .failed(_, let previous): previous
        case .loaded(let value): value
        case .idle, .unavailable: nil
        }
    }
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
