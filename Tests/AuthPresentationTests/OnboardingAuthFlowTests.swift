import Foundation
import XCTest
@testable import AuthPresentation

@MainActor
final class OnboardingAuthFlowTests: XCTestCase {
    func testDirectSignupReturnsToOnboardingAndPreservesDraftAcrossReentry() {
        var returnsToOnboarding = 0
        let flow = AuthFlowModel()
        flow.beginSignup()
        flow.signup.name = "김하늘"
        flow.signup.next()
        flow.leaveSignup { returnsToOnboarding += 1 }
        flow.showLogin()
        flow.beginSignup()
        XCTAssertEqual(flow.signup.name, "김하늘")
        XCTAssertEqual(flow.signup.step, .name)
        flow.leaveSignup { returnsToOnboarding += 1 }
        XCTAssertEqual(returnsToOnboarding, 2)
        flow.showLogin()
        flow.showSignup()
        flow.leaveSignup { returnsToOnboarding += 1 }
        XCTAssertEqual(flow.screen, .login)
        XCTAssertEqual(returnsToOnboarding, 2)
    }

    func testReturningToOnboardingCancelsLoginAndIgnoresLateSuccess() async {
        var continuation: CheckedContinuation<Void, Never>?
        var completions = 0
        let login = LoginViewModel { _, _ in
            await withCheckedContinuation { continuation = $0 }
        }
        login.email = "preview@example.com"; login.password = "preview123"
        let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
        let task = Task { await login.submit() }
        while continuation == nil { await Task.yield() }
        flow.cancel()
        continuation?.resume(); await task.value
        flow.reportSignIn()
        XCTAssertFalse(login.isSubmitting)
        XCTAssertFalse(login.didSignIn)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(login.email, "preview@example.com")
    }

    func testReturningToOnboardingCancelsResetAndIgnoresLateResponse() async {
        var continuation: CheckedContinuation<Void, Never>?
        let reset = PasswordResetViewModel { _ in
            await withCheckedContinuation { continuation = $0 }
        }
        let flow = AuthFlowModel(passwordReset: reset)
        reset.email = "preview@example.com"
        flow.showPasswordReset()
        let task = Task { await reset.submit() }
        while continuation == nil { await Task.yield() }
        flow.cancel()
        continuation?.resume(); await task.value
        XCTAssertFalse(reset.isSubmitting)
        XCTAssertFalse(reset.didSend)
        flow.showLogin(); flow.showPasswordReset()
        XCTAssertEqual(reset.email, "preview@example.com")
        XCTAssertFalse(reset.didSend)
    }

    func testDefaultEntryCannotReportAuthenticationWithoutInjectedService() async {
        var completions = 0
        let flow = AuthFlowModel(onSignedIn: { completions += 1 })
        flow.beginSignup(); flow.showLogin()
        flow.login.email = "preview@example.com"; flow.login.password = "preview123"
        await flow.login.submit(); flow.reportSignIn()
        XCTAssertNotNil(flow.login.errorMessage)
        XCTAssertFalse(flow.login.didSignIn)
        XCTAssertEqual(completions, 0)
    }
}
