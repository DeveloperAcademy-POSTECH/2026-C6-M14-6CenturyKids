import Foundation
import Observation

@MainActor @Observable
final class LoginViewModel {
    typealias SignIn = @MainActor @Sendable (String, String) async throws -> Void

    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var didSignIn = false
    private(set) var errorMessage: String?
    private(set) var hasSubmitted = false
    @ObservationIgnored private let signIn: SignIn
    @ObservationIgnored private var requestID = UUID()

    /// Composition root에서 AuthenticationService.signInPatient 호출을 주입합니다.
    init(signIn: @escaping SignIn = { _, _ in throw AuthPresentationError.unavailable }) {
        self.signIn = signIn
    }

    var emailError: String? { hasSubmitted ? AuthFormValidation.emailError(email) : nil }
    var passwordError: String? { hasSubmitted && password.isEmpty ? "비밀번호를 입력해 주세요." : nil }

    func submit() async {
        guard !Task.isCancelled, !isSubmitting, !didSignIn else { return }
        hasSubmitted = true
        errorMessage = nil
        guard AuthFormValidation.emailError(email) == nil, !password.isEmpty else { return }
        let id = UUID()
        requestID = id
        isSubmitting = true
        defer { if requestID == id { isSubmitting = false } }
        do {
            try await signIn(AuthFormValidation.trimmed(email), password)
            guard requestID == id, !Task.isCancelled else { return }
            password = ""
            didSignIn = true
        } catch {
            guard requestID == id, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = AuthPresentationError.message(for: error, fallback: "로그인하지 못했어요. 이메일과 비밀번호를 확인하고 다시 시도해 주세요.")
        }
    }

    func cancel() {
        requestID = UUID()
        isSubmitting = false
        errorMessage = nil
    }
}
