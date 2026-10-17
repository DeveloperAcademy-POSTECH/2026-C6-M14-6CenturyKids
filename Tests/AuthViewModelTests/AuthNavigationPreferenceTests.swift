import XCTest
@testable import ToDocFeatures

@MainActor final class AuthNavigationPreferenceTests: XCTestCase {
    func testUncheckedLoginDoesNotRestoreOnNextLaunch() async throws {
        let f = AuthFixture(); try f.addProfile()
        let preference = AuthLoginPreference()
        let first = AuthFlowViewModel(repositories: f.repositories, loginPreference: preference)
        first.login.state.email = "patient@example.com"; first.login.state.password = "password"
        await first.login.submit()
        XCTAssertNotNil(first.session.patient)
        let next = AuthFlowViewModel(repositories: f.repositories, loginPreference: preference)
        await next.restoreSessionOnce()
        XCTAssertNil(next.session.patient); XCTAssertFalse(f.auth.signedIn)
    }

    func testCheckedSuccessfulLoginRestoresButFailedLoginDoesNotOptIn() async throws {
        let f = AuthFixture(); try f.addProfile()
        let preference = AuthLoginPreference()
        let flow = AuthFlowViewModel(repositories: f.repositories, loginPreference: preference)
        flow.login.state.email = "patient@example.com"; flow.login.state.password = "password"
        flow.login.state.remembersLogin = true
        f.auth.signInError = AuthFlowError("테스트 실패")
        await flow.login.submit()
        XCTAssertFalse(preference.isEnabled)
        f.auth.signInError = nil
        await flow.login.submit()
        XCTAssertTrue(preference.isEnabled)
        let next = AuthFlowViewModel(repositories: f.repositories, loginPreference: preference)
        await next.restoreSessionOnce()
        XCTAssertEqual(next.session.patient?.user.id, f.auth.id)
    }

    func testPreferencePersistsOnlyChoiceAcrossInstances() {
        let suite = "AuthPreferenceTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AuthLoginPreference(defaults: defaults)
        XCTAssertFalse(first.isEnabled)
        first.isEnabled = true
        XCTAssertTrue(AuthLoginPreference(defaults: defaults).isEnabled)
        XCTAssertEqual(defaults.persistentDomain(forName: suite)?.count, 1)
    }

    func testIntroAdvancesEveryPageAndLastPageOpensSignup() {
        let flow = AuthFlowViewModel()
        for page in 1...4 {
            flow.advanceOnboarding()
            XCTAssertEqual(flow.onboarding.page, page); XCTAssertFalse(flow.showsAuth)
        }
        flow.advanceOnboarding()
        XCTAssertTrue(flow.showsAuth); XCTAssertEqual(flow.screen, .signup)
        flow.backFromSignup(); XCTAssertFalse(flow.showsAuth)
    }

    func testSignupBackRespectsEntryAndCompletedSignupStartsFresh() {
        let flow = AuthFlowViewModel()
        flow.open(.login); flow.open(.signup)
        flow.backFromSignup()
        XCTAssertTrue(flow.showsAuth); XCTAssertEqual(flow.screen, .login)
        flow.signup.state.step = .completion; flow.signup.state.email = "old@example.com"
        flow.signup.state.isAccountLocked = true
        let previous = flow.signup
        flow.open(.signup)
        XCTAssertFalse(flow.signup === previous)
        XCTAssertEqual(flow.signup.state.step, .role); XCTAssertEqual(flow.signup.state.email, "")
        XCTAssertFalse(flow.signup.state.isAccountLocked)
        flow.signup.state.name = "작성 중"
        let draft = flow.signup
        flow.backFromSignup(); flow.open(.signup)
        XCTAssertTrue(flow.signup === draft); XCTAssertEqual(flow.signup.state.name, "작성 중")
    }

    func testRecoveryDisablesRememberedLoginAndNewRequestClearsCleanupState() async {
        let f = AuthFixture(); let preference = AuthLoginPreference(); preference.isEnabled = true
        var repos = f.repositories; repos.callbacks = TestCallbacks(auth: f.auth)
        let url = URL(string: "todoc-test://auth/callback")!
        let flow = AuthFlowViewModel(repositories: repos, configuration: .init(redirectURL: url), loginPreference: preference)
        await flow.handleURL(url)
        XCTAssertFalse(preference.isEnabled)
        flow.reset.state.newPassword = "newPass123"; flow.reset.state.passwordConfirmation = "newPass123"
        f.auth.failSignOut = true
        await flow.reset.submit()
        XCTAssertTrue(flow.reset.state.needsSessionCleanup)
        f.auth.failSignOut = false
        flow.reset.cancel()
        while flow.session.isBusy { await Task.yield() }
        flow.reset.prepareEmailRequest()
        XCTAssertFalse(flow.reset.state.needsSessionCleanup); XCTAssertFalse(flow.reset.state.isRecoveryReady)
        XCTAssertFalse(flow.reset.state.didUpdatePassword); XCTAssertFalse(f.auth.signedIn)
    }
}
