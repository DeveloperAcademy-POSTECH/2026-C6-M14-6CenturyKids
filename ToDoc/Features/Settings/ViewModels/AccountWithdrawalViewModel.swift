import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AccountWithdrawalViewModel {
    private let authRepository: any AuthRepository
    private let authSession: AuthSessionState

    var password = ""
    private(set) var isWithdrawing = false
    private(set) var errorMessage: String?
    private(set) var didWithdraw = false

    init(authRepository: any AuthRepository, authSession: AuthSessionState) {
        self.authRepository = authRepository
        self.authSession = authSession
    }

    func withdrawEmailAccount() async {
        guard !isWithdrawing, !didWithdraw, !password.isEmpty else { return }

        isWithdrawing = true
        errorMessage = nil
        let password = password
        defer { isWithdrawing = false }

        do {
            let currentUserId = try await authRepository.getCurrentUserId()
            guard let currentEmail = try await authRepository.getCurrentUserEmail(), !currentEmail.isEmpty else {
                errorMessage = "계정 이메일을 확인하지 못했어요. 다시 로그인해 주세요."
                return
            }
            let verifiedUserId = try await authRepository.signIn(email: currentEmail, password: password)
            guard verifiedUserId == currentUserId else {
                errorMessage = "계정 정보를 확인하지 못했어요. 다시 로그인해 주세요."
                return
            }
            try await authRepository.deleteAccount()
            completeWithdrawal()
        } catch {
            errorMessage = "탈퇴하지 못했어요. 비밀번호와 네트워크 연결을 확인해 주세요."
        }
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        guard !isWithdrawing, !didWithdraw else { return }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = credential.authorizationCode,
                  let authorizationCode = String(data: codeData, encoding: .utf8),
                  !authorizationCode.isEmpty else {
                errorMessage = "Apple 인증 코드를 받지 못했어요. 다시 시도해 주세요."
                return
            }
            await withdrawAppleAccount(authorizationCode: authorizationCode)
        case .failure(let error):
            if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return }
            errorMessage = "Apple 재인증에 실패했어요. 다시 시도해 주세요."
        }
    }

    func withdrawAppleAccount(authorizationCode: String) async {
        guard !isWithdrawing, !didWithdraw else { return }
        guard !authorizationCode.isEmpty else {
            errorMessage = "Apple 인증 코드를 받지 못했어요. 다시 시도해 주세요."
            return
        }

        isWithdrawing = true
        errorMessage = nil
        defer { isWithdrawing = false }
        do {
            try await authRepository.withdrawAppleAccount(authorizationCode: authorizationCode)
            completeWithdrawal()
        } catch {
            errorMessage = "탈퇴하지 못했어요. Apple 인증과 네트워크 연결을 확인해 주세요."
        }
    }

    private func completeWithdrawal() {
        authSession.loginPreference.isEnabled = false
        authSession.patient = nil
        password = ""
        didWithdraw = true
    }
}
