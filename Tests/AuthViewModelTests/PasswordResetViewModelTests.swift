#if canImport(Auth)
import XCTest
import enum Auth.AuthError
import struct Auth.ErrorCode
@testable import ToDocAuth

/// 이메일 → 인증코드 → 새 비밀번호 → 로그아웃 순서를 가짜 저장소로 검증합니다.
@MainActor final class PasswordResetViewModelTests: XCTestCase {
    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "Untrusted server detail", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.invalid/auth")!,
                                                  statusCode: 403, httpVersion: nil, headerFields: nil)!)
    }
    /// 인증코드 확인까지 마친 VM입니다.
    private func verified(_ f: AuthFixture) async -> PasswordResetViewModel {
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        vm.state.email = "  patient@example.com  "
        await vm.submit()
        vm.state.code = " 123456 "
        await vm.submit()
        return vm
    }

    func testCodeOpensRecoveryAndNewPasswordSignsOut() async {
        let f = AuthFixture(); f.session.loginPreference.isEnabled = true
        let vm = await verified(f)
        XCTAssertEqual(f.auth.resetCount, 1)
        XCTAssertEqual(f.auth.lastEmail, "patient@example.com"); XCTAssertEqual(f.auth.lastCode, "123456")
        XCTAssertTrue(vm.state.isRecoveryReady)
        XCTAssertFalse(f.session.loginPreference.isEnabled, "복구 세션을 다음 실행에서 로그인으로 복원하지 않습니다.")

        vm.state.newPassword = "newPass12!"; vm.state.passwordConfirmation = "newPass12!"
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1); XCTAssertEqual(f.auth.signOutCount, 1)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertTrue(vm.state.didUpdatePassword)
        XCTAssertTrue(vm.state.newPassword.isEmpty); XCTAssertNil(f.session.patient)
    }

    func testWrongCodeStaysOnCodeStep() async {
        let f = AuthFixture(); f.auth.verifyError = apiError(.otpExpired)
        let vm = await verified(f)
        XCTAssertFalse(vm.state.isRecoveryReady); XCTAssertTrue(vm.state.didSend)
        XCTAssertNotNil(vm.state.codeError)
        XCTAssertFalse(vm.state.isSubmitting)
    }

    func testMismatchedConfirmationDoesNotWrite() async {
        let f = AuthFixture(); let vm = await verified(f)
        vm.state.newPassword = "newPass12!"; vm.state.passwordConfirmation = "newPass12?"
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 0); XCTAssertNotNil(vm.state.confirmationError)
    }

    func testFailedSignOutCanBeRetried() async {
        let f = AuthFixture(); let vm = await verified(f)
        f.auth.failSignOut = true
        vm.state.newPassword = "newPass12!"; vm.state.passwordConfirmation = "newPass12!"
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertTrue(vm.state.needsSessionCleanup); XCTAssertFalse(vm.state.didUpdatePassword)

        f.auth.failSignOut = false
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1, "정리 재시도는 비밀번호를 다시 바꾸지 않습니다.")
        XCTAssertFalse(f.auth.signedIn); XCTAssertTrue(vm.state.didUpdatePassword)
    }

    func testLeavingAfterVerifiedCodeEndsRecoverySession() async {
        let f = AuthFixture(); let vm = await verified(f)
        XCTAssertTrue(f.auth.signedIn)
        vm.cancel()
        for _ in 0..<20 where f.auth.signedIn { await Task.yield() }
        XCTAssertFalse(f.auth.signedIn); XCTAssertFalse(f.session.isBusy)
        XCTAssertEqual(f.auth.updateCount, 0)
    }
}
#endif
