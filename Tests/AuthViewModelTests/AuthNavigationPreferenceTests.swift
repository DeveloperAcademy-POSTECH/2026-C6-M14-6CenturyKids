import XCTest
@testable import ToDocAuth

@MainActor final class AuthNavigationPreferenceTests: XCTestCase {
    func testSuccessfulLoginPersistsByDefaultAcrossAppInstances() async throws {
        let f = AuthFixture(); try f.addProfile()
        let suite = "DefaultLoginTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AuthFlowViewModel(repositories: f.repositories,
                                      session: AuthSessionState(loginPreference: AuthLoginPreference(defaults: defaults)))
        first.login.state.email = "patient@example.com"; first.login.state.password = "password"
        await first.login.submit()
        XCTAssertNotNil(first.session.patient)
        let next = AuthFlowViewModel(repositories: f.repositories,
                                     session: AuthSessionState(loginPreference: AuthLoginPreference(defaults: defaults)))
        await next.restoreSessionOnce()
        XCTAssertEqual(next.session.patient?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.signInCount, 1, "복원할 때 비밀번호 로그인을 다시 요청하지 않습니다.")
        XCTAssertTrue(f.auth.signedIn)
    }

    func testUnverifiedSDKSessionDoesNotRestore() async {
        let f = AuthFixture(); f.auth.signedIn = true
        let flow = AuthFlowViewModel(repositories: f.repositories, session: AuthSessionState())
        await flow.restoreSessionOnce()
        XCTAssertNil(flow.session.patient)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertEqual(f.patients.finds, 0)
    }

    func testFailedLoginCannotRestoreButSuccessfulRetryCan() async throws {
        let f = AuthFixture(); try f.addProfile()
        let preference = AuthLoginPreference()
        let flow = AuthFlowViewModel(repositories: f.repositories, session: AuthSessionState(loginPreference: preference))
        flow.login.state.email = "patient@example.com"; flow.login.state.password = "password"
        f.auth.signInError = AuthFlowError("테스트 실패")
        await flow.login.submit()
        XCTAssertFalse(preference.isEnabled)
        f.auth.signInError = nil
        await flow.login.submit()
        XCTAssertTrue(preference.isEnabled)
        let next = AuthFlowViewModel(repositories: f.repositories, session: AuthSessionState(loginPreference: preference))
        await next.restoreSessionOnce()
        XCTAssertEqual(next.session.patient?.user.id, f.auth.id)
    }

    func testPreferencePersistsOnlySuccessfulLoginFlagAcrossInstances() {
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
        let flow = AuthFlowViewModel(session: AuthSessionState())
        for page in 1...4 {
            flow.advanceOnboarding()
            XCTAssertEqual(flow.onboarding.page, page); XCTAssertFalse(flow.showsAuth)
        }
        flow.advanceOnboarding()
        XCTAssertTrue(flow.showsAuth); XCTAssertEqual(flow.screen, .signup)
        flow.backFromSignup(); XCTAssertFalse(flow.showsAuth)
    }

    func testSignupBackRespectsEntryAndCompletedSignupStartsFresh() {
        let flow = AuthFlowViewModel(session: AuthSessionState())
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

}
