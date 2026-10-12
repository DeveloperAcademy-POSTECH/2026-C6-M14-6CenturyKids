import Foundation
import XCTest
@testable import AuthPresentation

@MainActor
final class AuthFlowModelTests: XCTestCase {
    private func signup(_ action: @escaping SignupViewModel.SignUp = { _ in }) -> SignupViewModel {
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 전용 약관") }), signUp: action)
        fill(model)
        return model
    }
    private func fill(_ model: SignupViewModel) {
        model.name = "김하늘"; model.email = " patient@example.com "
        model.password = "password123"; model.passwordConfirmation = model.password
        model.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        model.birthday = Date(timeIntervalSince1970: 0); model.sex = .female
        model.cancerType = .breast; model.stage = .known(.stage2)
    }

    func testSignupRoundTripUsesOriginalLoginAndDeliversSuccessOnlyOnce() async {
        var completions = 0
        let login = LoginViewModel { email, password in
            XCTAssertEqual(email, "patient@example.com")
            XCTAssertEqual(password, "login1234")
        }
        login.password = "old draft"
        let draft = signup()
        let flow = AuthFlowModel(login: login, signup: draft, onSignedIn: { completions += 1 })
        flow.showSignup()
        draft.name = "김가을"
        flow.showLogin()
        flow.showSignup()
        XCTAssertEqual(flow.signup.name, "김가을")
        await flow.signup.submit()
        flow.completeSignup()
        XCTAssertEqual(flow.screen, .login)
        XCTAssertTrue(flow.login === login)
        XCTAssertEqual(flow.login.email, "patient@example.com")
        XCTAssertTrue(flow.login.password.isEmpty)
        XCTAssertEqual(completions, 0)
        flow.login.password = "login1234"
        await flow.login.submit()
        flow.reportSignIn()
        flow.reportSignIn()
        XCTAssertEqual(completions, 1)
    }

    func testFailureStaysOnLoginAndRetryCanFinish() async {
        var calls = 0
        var completions = 0
        let login = LoginViewModel { _, _ in
            calls += 1
            if calls == 1 { throw AuthPresentationError.message("테스트 실패") }
        }
        login.email = "p@example.com"; login.password = "password"
        let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
        await flow.login.submit(); flow.reportSignIn()
        XCTAssertEqual(flow.screen, .login)
        XCTAssertNotNil(flow.login.errorMessage)
        XCTAssertEqual(completions, 0)
        await flow.login.submit(); flow.reportSignIn()
        XCTAssertNil(flow.login.errorMessage)
        XCTAssertEqual(completions, 1)
    }

    func testLeavingLoginIgnoresLateSuccessfulResponse() async {
        var continuation: CheckedContinuation<Void, Never>?
        var completions = 0
        let login = LoginViewModel { _, _ in
            await withCheckedContinuation { continuation = $0 }
        }
        login.email = "p@example.com"; login.password = "password"
        let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
        let request = Task { await flow.login.submit() }
        while continuation == nil { await Task.yield() }
        flow.showSignup()
        continuation?.resume(); await request.value
        flow.reportSignIn()
        XCTAssertEqual(flow.screen, .signup)
        XCTAssertFalse(login.didSignIn)
        XCTAssertEqual(completions, 0)
    }

    func testIncompleteSignupCannotNavigateToLoginAsCompleted() {
        let flow = AuthFlowModel(entry: .signup, signup: signup())
        flow.completeSignup()
        XCTAssertEqual(flow.screen, .signup)
    }

    func testNewSignupAfterCompletionRetainsInjectedActionWithFreshDraft() async {
        var calls = 0
        let draft = signup { _ in calls += 1 }
        let flow = AuthFlowModel(signup: draft)
        flow.showSignup(); await flow.signup.submit(); flow.completeSignup()
        flow.showSignup()
        XCTAssertEqual(flow.signup.step, .role)
        XCTAssertTrue(flow.signup.email.isEmpty)
        XCTAssertTrue(flow.signup.password.isEmpty)
        fill(flow.signup)
        await flow.signup.submit()
        XCTAssertEqual(flow.signup.step, .completion)
        XCTAssertEqual(calls, 2)
    }

    func testSignupEntryDismissesInitiallyButReturnsToLoginAfterReentry() async {
        var dismissals = 0
        let flow = AuthFlowModel(entry: .signup, signup: signup())
        flow.leaveSignup { dismissals += 1 }
        XCTAssertEqual(dismissals, 1)
        await flow.signup.submit()
        flow.completeSignup()
        flow.showSignup()
        flow.leaveSignup { dismissals += 1 }
        XCTAssertEqual(flow.screen, .login)
        XCTAssertEqual(dismissals, 1)
    }

    func testResetCanReopenAndUsesInjectedAction() async {
        var emails: [String] = []
        let reset = PasswordResetViewModel { emails.append($0) }
        let login = LoginViewModel(); login.email = " p@example.com "
        let flow = AuthFlowModel(login: login, passwordReset: reset)
        flow.showPasswordReset()
        XCTAssertEqual(flow.screen, .passwordReset)
        await flow.passwordReset.submit()
        XCTAssertTrue(flow.passwordReset.didSend)
        flow.showLogin(); flow.showPasswordReset()
        XCTAssertFalse(flow.passwordReset.didSend)
        XCTAssertFalse(flow.passwordReset.isSubmitting)
        await flow.passwordReset.submit()
        XCTAssertEqual(emails, ["p@example.com", "p@example.com"])
    }
}
