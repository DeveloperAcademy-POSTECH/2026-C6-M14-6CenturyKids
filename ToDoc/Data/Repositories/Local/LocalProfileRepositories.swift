import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// A fixed, device-local identity. There is no account, credential or server session.
enum OfflineProfile {
    static let id = UUID(uuidString: "C6000000-0000-4000-8000-000000000001")!
    static func prepare(store: LocalFileStore) throws {
        try store.locked {
            if try store.read(UserDTO.self, collection: "users", id: id) == nil {
                let user = try User(id: id, name: "체험자", birthday: Date(timeIntervalSince1970: 0), sex: .female)
                try store.write(UserDTO(user: user), collection: "users", id: id)
            }
            if try store.read(PatientDTO.self, collection: "patients", id: id) == nil {
                let user = try store.read(UserDTO.self, collection: "users", id: id)!.toDomain()
                try store.write(PatientDTO(patient: Patient(user: user, doctorId: nil, disease: nil)), collection: "patients", id: id)
            }
        }
    }
}

final class LocalUserRepository: UserRepository {
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func save(user: User) async throws { try store.write(UserDTO(user: user), collection: "users", id: user.id) }
    func findById(_ id: UUID) async throws -> User? { try store.read(UserDTO.self, collection: "users", id: id)?.toDomain() }
    func findByName(_ name: String) async throws -> [User] {
        try store.all(UserDTO.self, collection: "users").filter { $0.name == name }.map { try $0.toDomain() }
    }
}

final class LocalPatientRepository: PatientRepository {
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func save(patient: Patient) async throws {
        try store.write(PatientDTO(patient: patient), collection: "patients", id: patient.user.id)
    }
    func findById(_ id: UUID) async throws -> Patient? {
        guard let patient = try store.read(PatientDTO.self, collection: "patients", id: id),
              let user = try store.read(UserDTO.self, collection: "users", id: id)?.toDomain() else { return nil }
        return try patient.toDomain(user: user)
    }
    func findByName(_ name: String) async throws -> [Patient] {
        guard let patient = try await findById(OfflineProfile.id), patient.user.name == name else { return [] }
        return [patient]
    }
    func findByDoctorId(_ doctorId: UUID) async throws -> [Patient] { [] }
    func connectToDoctor(code: String) async throws { throw LocalStoreError.unavailableAccountAction }
    func disconnectFromDoctor() async throws {
        guard let patient = try await findById(OfflineProfile.id) else { return }
        try await save(patient: Patient(user: patient.user, doctorId: nil, disease: patient.disease))
    }
}

final class LocalAuthRepository: AuthRepository {
    func getCurrentUserId() async throws -> UUID { OfflineProfile.id }
    func getCurrentUserEmail() async throws -> String? { nil }
    func isSignedIn() -> Bool { true }
    func getSignUpProvider() async throws -> String? { nil }
    func signOut() async throws { throw LocalStoreError.unavailableAccountAction }
    func signUp(email: String, password: String) async throws -> UUID { throw LocalStoreError.unavailableAccountAction }
    func signIn(email: String, password: String) async throws -> UUID { throw LocalStoreError.unavailableAccountAction }
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { throw LocalStoreError.unavailableAccountAction }
    func signInWithKakao(idToken: String) async throws -> UUID { throw LocalStoreError.unavailableAccountAction }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws { throw LocalStoreError.unavailableAccountAction }
    func requestPasswordChangeVerification() async throws { throw LocalStoreError.unavailableAccountAction }
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws { throw LocalStoreError.unavailableAccountAction }
    func updatePassword(to newPassword: String, nonce: String?) async throws { throw LocalStoreError.unavailableAccountAction }
    func deleteAccount() async throws { throw LocalStoreError.unavailableAccountAction }
    func withdrawAppleAccount(authorizationCode: String) async throws { throw LocalStoreError.unavailableAccountAction }
    func withdrawKakaoAccount() async throws { throw LocalStoreError.unavailableAccountAction }
}

final class OfflineDoctorRepository: DoctorRepository {
    func save(doctor: Doctor) async throws { throw LocalStoreError.unavailableAccountAction }
    func findById(_ id: UUID) async throws -> Doctor? { nil }
    func findByName(_ name: String) async throws -> [Doctor] { [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { [] }
    func findByCode(_ code: String) async throws -> Doctor? { nil }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? { nil }
}

final class OfflineHospitalRepository: HospitalRepository {
    func findById(_ id: UUID) async throws -> Hospital? { nil }
    func findByName(_ name: String) async throws -> [Hospital] { [] }
    func findByCode(_ code: String) async throws -> Hospital? { nil }
    func searchByAddress(_ keyword: String) async throws -> [Hospital] { [] }
}

final class LocalNotificationSettingsRepository: NotificationSettingsRepository {
    private let store: LocalFileStore
    init(store: LocalFileStore) { self.store = store }
    func fetch(userId: UUID) async throws -> NotificationSettingsDTO? {
        try store.read(NotificationSettingsDTO.self, collection: "notification-settings", id: userId)
    }
    func save(settings: NotificationSettingsDTO) async throws {
        try store.write(settings, collection: "notification-settings", id: settings.userId)
    }
}

final class OfflineDeviceTokenRepository: DeviceTokenRepository {
    func save(token: DeviceTokenDTO) async throws {}
    func removeToken(userId: UUID, installationId: String) async throws {}
    func testStartLiveActivity() async throws { throw LocalStoreError.unavailableAccountAction }
}
