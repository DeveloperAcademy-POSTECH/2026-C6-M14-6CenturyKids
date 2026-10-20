import Foundation
import Observation

@MainActor
@Observable
final class PatientFlowViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(patientId: UUID)
        case failed
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let authRepository: any AuthRepository
    @ObservationIgnored private let patientRepository: any PatientRepository

    init(
        authRepository: any AuthRepository,
        patientRepository: any PatientRepository
    ) {
        self.authRepository = authRepository
        self.patientRepository = patientRepository
    }

    func loadPatient() async {
        guard state != .loading else { return }
        if case .loaded = state { return }

        state = .loading

        do {
            let userId = try await authRepository.getCurrentUserId()
            guard let patient = try await patientRepository.findById(userId) else {
                state = .failed
                return
            }

            state = .loaded(patientId: patient.user.id)
        } catch {
            state = .failed
        }
    }
}
