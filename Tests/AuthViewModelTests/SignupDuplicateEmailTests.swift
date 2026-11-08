#if canImport(Auth)
import XCTest
import enum Auth.AuthError
import struct Auth.ErrorCode
@testable import ToDocAuth

/// SDK 오류를 직접 사용하지만 네트워크 요청이나 실제 계정 생성은 하지 않습니다.
@MainActor final class SignupDuplicateEmailTests: XCTestCase {
    private let message = "이미 가입된 이메일이에요. 기존 계정으로 로그인해 주세요."

    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "Untrusted server detail", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.invalid/auth")!,
                                                  statusCode: 422, httpVersion: nil, headerFields: nil)!)
    }

    private func flow(_ fixture: AuthFixture) -> AuthFlowViewModel {
        var configuration = SignupResetTests().configuration
        configuration.allowsSignupRequests = true
        let flow = AuthFlowViewModel(repositories: fixture.repositories, configuration: configuration, session: AuthSessionState())
        flow.open(.signup)
        SignupResetTests().ready(flow.signup)
        flow.signup.state.step = .terms
        return flow
    }

    func testBothDuplicateCodesStopBeforeProfileAccessAndClearPasswords() async {
        for code: ErrorCode in [.emailExists, .userAlreadyExists] {
            let f = AuthFixture(), flow = flow(f), vm = flow.signup
            f.auth.signUpError = apiError(code)
            await vm.continueFromTerms()
            XCTAssertTrue(vm.state.isEmailAlreadyRegistered)
            XCTAssertEqual(vm.state.errorMessage, message)
            XCTAssertTrue(vm.state.isAccountLocked)
            XCTAssertEqual(vm.state.step, .terms)
            XCTAssertEqual(f.auth.signUpCount, 1)
            XCTAssertEqual(f.auth.signInCount, 0)
            XCTAssertEqual(f.users.finds, 0)
            XCTAssertEqual(f.users.saves, 0)
            XCTAssertEqual(f.patients.finds, 0)
            XCTAssertEqual(f.patients.saves, 0)
            XCTAssertNil(vm.completedPatient)
            XCTAssertNil(flow.session.patient)
            XCTAssertFalse(flow.session.isBusy)
            XCTAssertFalse(vm.state.isWorking)
            XCTAssertFalse(vm.state.isAwaitingEmailConfirmation)
            XCTAssertTrue(vm.state.password.isEmpty)
            XCTAssertTrue(vm.state.passwordConfirmation.isEmpty)
        }
    }

    func testRepeatedSubmitAndBackPreserveDuplicateMessageWithoutAnotherRequest() async {
        let f = AuthFixture(), vm = flow(f).signup
        f.auth.signUpError = apiError(.userAlreadyExists)
        await vm.continueFromTerms()
        vm.handle(.back)
        XCTAssertEqual(vm.state.errorMessage, message)
        await vm.continueFromTerms()
        XCTAssertEqual(vm.state.errorMessage, message)
        XCTAssertEqual(f.auth.signUpCount, 1)
    }

    func testLoginActionTransfersOnlyNormalizedEmailAndExistingLoginWorks() async throws {
        let f = AuthFixture(), flow = flow(f)
        flow.signup.state.email = "  patient@example.com  "
        flow.login.state.password = "previous-password"
        f.auth.signUpError = apiError(.emailExists)
        await flow.signup.continueFromTerms()
        flow.loginAfterSignup()
        XCTAssertEqual(flow.screen, .login)
        XCTAssertTrue(flow.showsAuth)
        XCTAssertEqual(flow.rootRoute, .authentication)
        XCTAssertEqual(flow.login.state.email, "patient@example.com")
        XCTAssertTrue(flow.login.state.password.isEmpty)
        XCTAssertEqual(f.auth.signInCount, 0)
        try f.addProfile()
        flow.login.state.password = "existing-password"
        await flow.login.submit()
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertEqual(f.auth.signInCount, 1)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.patients.saves, 0)
    }

    func testRestartAfterDuplicateAllowsDifferentEmailThroughNormalSignup() async {
        let f = AuthFixture(), flow = flow(f), previous = flow.signup
        f.auth.signUpError = apiError(.userAlreadyExists)
        await previous.continueFromTerms()
        flow.restartSignupAfterConfirmation()
        XCTAssertFalse(flow.signup === previous)
        XCTAssertFalse(flow.signup.state.isEmailAlreadyRegistered)
        XCTAssertFalse(flow.signup.state.isAccountLocked)
        XCTAssertTrue(flow.signup.state.email.isEmpty)
        SignupResetTests().ready(flow.signup)
        flow.signup.state.email = "new@example.com"
        f.auth.signUpError = nil
        flow.signup.state.step = .terms
        await flow.signup.continueFromTerms()
        flow.signup.state.step = .review
        await flow.signup.submit()
        XCTAssertEqual(flow.signup.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 2)
    }

    func testOtherCodesAndNetworkOrTextErrorsAreNotClassifiedAsDuplicates() async {
        let errors: [Error] = [apiError(.weakPassword), apiError(.unknown), apiError(.emailNotConfirmed),
                               URLError(.timedOut), AuthFlowError("user_already_exists: already registered")]
        for error in errors {
            let f = AuthFixture(), vm = flow(f).signup
            f.auth.signUpError = error
            await vm.continueFromTerms()
            XCTAssertFalse(vm.state.isEmailAlreadyRegistered)
            XCTAssertNotEqual(vm.state.errorMessage, message)
            await vm.continueFromTerms()
            XCTAssertEqual(f.auth.signUpCount, 1)
            XCTAssertEqual(f.users.saves, 0)
            XCTAssertEqual(f.patients.saves, 0)
        }
    }

    func testSameCodeDuringProfileReadIsNotASignupDuplicate() async {
        let f = AuthFixture(), vm = flow(f).signup
        await vm.continueFromTerms()
        vm.state.step = .review
        f.patients.findError = apiError(.emailExists)
        await vm.submit()
        XCTAssertFalse(vm.state.isEmailAlreadyRegistered)
        XCTAssertNotEqual(vm.state.errorMessage, message)
        f.patients.findError = nil
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
    }

    func testCancelledResponseDoesNotPublishDuplicateState() async {
        let f = AuthFixture(), vm = flow(f).signup
        f.auth.signUpError = apiError(.userAlreadyExists)
        f.auth.beforeSignUp = { vm.cancel() }
        await vm.continueFromTerms()
        XCTAssertFalse(vm.state.isEmailAlreadyRegistered)
        XCTAssertNil(vm.state.errorMessage)
        XCTAssertFalse(vm.state.isWorking)
        await vm.continueFromTerms()
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertNotEqual(vm.state.errorMessage, message)
    }
}
#endif
