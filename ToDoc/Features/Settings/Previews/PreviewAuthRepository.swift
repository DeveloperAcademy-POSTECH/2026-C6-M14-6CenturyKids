#if DEBUG
import Foundation

/// 서버 요청 없이 인증 화면을 확인하기 위한 Preview 전용 저장소입니다.
struct PreviewAuthRepository: AuthRepository {
    private let userID = UUID()
    private struct Unavailable: Error {}
    let provider: SignUpProvider
    
    init(provider: SignUpProvider = .email) {
        self.provider = provider
    }

    func getCurrentUserId() async throws -> UUID { userID }
    func getCurrentUserEmail() async throws -> String? { "preview@example.com" }
    func getSignUpProvider() async throws -> String? { provider.rawValue }
    func isSignedIn() -> Bool { false }

    // Preview에서 실제 인증이나 계정 삭제가 실행되지 않도록 실패를 반환합니다.
    func signUp(email: String, password: String) async throws -> UUID { throw Unavailable() }
    func signIn(email: String, password: String) async throws -> UUID { throw Unavailable() }
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { throw Unavailable() }
    func signInWithKakao(idToken: String) async throws -> UUID { throw Unavailable() }
    func signOut() async throws { throw Unavailable() }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws { throw Unavailable() }
    func requestPasswordChangeVerification() async throws { throw Unavailable() }
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws { throw Unavailable() }
    func updatePassword(to newPassword: String, nonce: String?) async throws { throw Unavailable() }
    func deleteAccount() async throws { throw Unavailable() }
    func withdrawAppleAccount(authorizationCode: String) async throws { throw Unavailable() }
}
#endif
