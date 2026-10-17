import Foundation
import ToDocDomain
@testable import ToDocFeatures

/// 테스트 전용 저장소입니다. 제품 DI에는 들어가지 않으며 실제 서버 계정을 만들지 않습니다.
final class TestAuthRepository: AuthRepository {
    let id = UUID()
    var signedIn = false
    var signInCount = 0
    var signUpCount = 0
    var resetCount = 0
    var updateCount = 0
    var signOutCount = 0
    var confirmEmail = false
    var failSignOut = false
    var failSignUp = false
    var failUpdate = false
    var beforeSignIn: (() async -> Void)?
    var beforeSignUp: (() async -> Void)?
    var signInError: Error?
    var lastEmail: String?
    var lastRedirect: URL?
    func signIn(email: String, password: String) async throws -> UUID {
        signInCount += 1; lastEmail = email
        await beforeSignIn?()
        if let signInError { throw signInError }
        signedIn = true; return id
    }
    func signUp(email: String, password: String) async throws -> UUID {
        signUpCount += 1
        await beforeSignUp?()
        if failSignUp { throw AuthFlowError("통신 실패") }
        signedIn = !confirmEmail; return id
    }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws { lastRedirect = url }
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { id }
    func signOut() async throws {
        signOutCount += 1
        if failSignOut { throw AuthFlowError("로그아웃 실패") }
        signedIn = false
    }
    func getCurrentUserId() async throws -> UUID {
        guard signedIn else { throw AuthFlowError("세션 없음") }; return id
    }
    func isSignedIn() -> Bool { signedIn }
    func requestPasswordChangeVerification() async throws {}
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws { resetCount += 1; lastRedirect = url }
    func updatePassword(to newPassword: String, nonce: String?) async throws {
        updateCount += 1; if failUpdate { throw AuthFlowError("변경 실패") }
    }
}
final class TestUsers: UserRepository {
    var normalizeBirthday = false
    var value: User?
    var saves = 0
    func save(user: User) async throws {
        saves += 1
        value = normalizeBirthday
            ? try User(id: user.id, name: user.name, birthday: Calendar.current.startOfDay(for: user.birthday), sex: user.sex)
            : user
    }
    func findById(_ id: UUID) async throws -> User? { value }
    func findByName(_ name: String) async throws -> [User] { value.map { [$0] } ?? [] }
}
final class TestPatients: PatientRepository {
    var value: Patient?
    var saves = 0
    var failNextSave = false
    func save(patient: Patient) async throws {
        saves += 1
        if failNextSave { failNextSave = false; throw AuthFlowError("저장 실패") }
        value = patient
    }
    func findById(_ id: UUID) async throws -> Patient? { value }
    func findByName(_ name: String) async throws -> [Patient] { [] }
    func findByDoctorId(_ doctorId: UUID) async throws -> [Patient] { [] }
}
final class TestConsents: SignupConsentRepository {
    var saved: [String] = []
    var saves = 0
    func saveConsent(userID: UUID, version: String, acceptedTermIDs: [String], acceptedAt: Date) async throws {
        saves += 1; saved = acceptedTermIDs
    }
}
@MainActor final class AuthFixture {
    let auth = TestAuthRepository()
    let users = TestUsers()
    let patients = TestPatients()
    let consents = TestConsents()
    let session = AuthSessionState()
    var repositories: AuthRepositories { .init(auth: auth, users: users, patients: patients, consents: consents) }
    func addProfile(id: UUID? = nil) throws {
        let user = try User(id: id ?? auth.id, name: "테스트", birthday: Date(timeIntervalSince1970: 946684800), sex: .female)
        users.value = user; patients.value = Patient(user: user, doctorId: nil, disease: nil)
    }
}
