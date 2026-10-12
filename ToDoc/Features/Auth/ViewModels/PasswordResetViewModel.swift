import Foundation
import Observation

@MainActor @Observable
final class PasswordResetViewModel {
    typealias ResetPassword = @MainActor @Sendable (String) async throws -> Void
    var email = ""
    private(set) var hasSubmitted = false
    private(set) var isSubmitting = false
    private(set) var didSend = false
    private(set) var errorMessage: String?
    @ObservationIgnored private let resetPassword: ResetPassword
    @ObservationIgnored private var requestID = UUID()

    init(resetPassword: @escaping ResetPassword = { _ in throw AuthPresentationError.unavailable }) {
        self.resetPassword = resetPassword
    }

    var emailError: String? { hasSubmitted ? AuthFormValidation.emailError(email) : nil }

    func submit() async {
        guard !Task.isCancelled, !isSubmitting, !didSend else { return }
        hasSubmitted = true
        errorMessage = nil
        guard AuthFormValidation.emailError(email) == nil else { return }
        let id = UUID()
        requestID = id
        isSubmitting = true
        defer { if requestID == id { isSubmitting = false } }
        do {
            try await resetPassword(AuthFormValidation.trimmed(email))
            guard requestID == id, !Task.isCancelled else { return }
            didSend = true
        } catch {
            guard requestID == id, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = AuthPresentationError.message(for: error, fallback: "요청을 보내지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    func prepareForRequest() {
        cancel()
        didSend = false
        hasSubmitted = false
        errorMessage = nil
    }

    func cancel() {
        requestID = UUID()
        isSubmitting = false
    }
}
