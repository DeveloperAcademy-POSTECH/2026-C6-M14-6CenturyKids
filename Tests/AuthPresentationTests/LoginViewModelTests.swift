import XCTest
@testable import AuthPresentation

@MainActor
final class LoginViewModelTests: XCTestCase {
    func testInvalidLoginNeverCallsService() async {
        var calls = 0
        let model = LoginViewModel(signIn: { _, _ in calls += 1 })
        model.email = "wrong"
        model.password = "secret"
        await model.submit()
        XCTAssertEqual(calls, 0)
        XCTAssertNotNil(model.emailError)
    }

    func testFailureCanRetryAndPasswordIsNeverTrimmed() async {
        var calls = 0
        let model = LoginViewModel { email, password in
            XCTAssertEqual(email, "patient@example.com")
            XCTAssertEqual(password, " password ")
            calls += 1
            if calls == 1 { throw AuthPresentationError.message("다시 확인해 주세요.") }
        }
        model.email = " patient@example.com "
        model.password = " password "
        await model.submit()
        XCTAssertFalse(model.didSignIn)
        XCTAssertNotNil(model.errorMessage)
        await model.submit()
        XCTAssertTrue(model.didSignIn)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.password, "")
    }

    func testDuplicateAndCancelledResponseCannotFinishLogin() async {
        var continuation: CheckedContinuation<Void, Never>?
        var calls = 0
        let model = LoginViewModel { _, _ in
            calls += 1
            await withCheckedContinuation { continuation = $0 }
        }
        model.email = "p@example.com"
        model.password = "password"
        let request = Task { await model.submit() }
        while continuation == nil { await Task.yield() }
        await model.submit()
        XCTAssertEqual(calls, 1)
        model.cancel()
        continuation?.resume()
        await request.value
        XCTAssertFalse(model.didSignIn)
        XCTAssertFalse(model.isSubmitting)
        XCTAssertNil(model.errorMessage)
    }

    func testUnconnectedServiceDoesNotReportSuccess() async {
        let model = LoginViewModel()
        model.email = "p@example.com"
        model.password = "password"
        await model.submit()
        XCTAssertFalse(model.didSignIn)
        XCTAssertNotNil(model.errorMessage)
    }

    func testPasswordResetValidatesAndOnlyCompletesAfterService() async {
        var submitted: String?
        let model = PasswordResetViewModel { submitted = $0 }
        await model.submit()
        XCTAssertNil(submitted)
        model.email = " p@example.com "
        await model.submit()
        XCTAssertEqual(submitted, "p@example.com")
        XCTAssertTrue(model.didSend)
    }
    func testAlreadyCancelledLoginAndResetNeverCallService() async {
        var calls = 0
        let login = LoginViewModel { _, _ in calls += 1 }
        login.email = "p@example.com"; login.password = "password"
        let loginTask = Task { await login.submit() }
        loginTask.cancel()
        await loginTask.value
        let reset = PasswordResetViewModel { _ in calls += 1 }
        reset.email = "p@example.com"
        let resetTask = Task { await reset.submit() }
        resetTask.cancel()
        await resetTask.value
        XCTAssertEqual(calls, 0)
    }

}
