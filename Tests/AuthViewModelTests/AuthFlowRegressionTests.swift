import XCTest
@testable import ToDocFeatures

@MainActor final class AuthFlowRegressionTests: XCTestCase {
    private let config = AuthConfiguration(redirectURL: URL(string: "todoc-test://auth/callback"))

    func testRecoveryKeepsAuthenticationRouteWhileCallbackIsPending() async {
        let f = AuthFixture(); let callback = TestCallbacks(auth: f.auth)
        var repositories = f.repositories; repositories.callbacks = callback
        let flow = AuthFlowViewModel(repositories: repositories, configuration: config)
        flow.open(.passwordReset)
        flow.reset.state.didSend = true
        callback.beforeRecovery = {
            // 화면을 교체하는 progress 경로로 바뀌면 onDisappear가 복구 요청을 취소합니다.
            // 진행 표시는 현재 인증 화면 위에 겹쳐 표시해야 합니다.
            await Task.yield()
            XCTAssertTrue(flow.isHandlingLink)
            XCTAssertEqual(flow.rootRoute, .authentication)
            XCTAssertEqual(flow.screen, .passwordReset)
        }
        await flow.handleURL(config.redirectURL!)
        XCTAssertTrue(flow.reset.state.isRecoveryReady)
        XCTAssertNil(flow.linkMessage)
    }

    func testSameFlowCanLoginAgainAfterPasswordRecovery() async throws {
        let f = AuthFixture(); try f.addProfile()
        var repositories = f.repositories; repositories.callbacks = TestCallbacks(auth: f.auth)
        let flow = AuthFlowViewModel(repositories: repositories, configuration: config)
        flow.login.state.email = "patient@example.com"; flow.login.state.password = "oldPass123"
        await flow.login.submit()
        XCTAssertNotNil(flow.session.patient)
        await flow.handleURL(config.redirectURL!)
        flow.reset.state.newPassword = "newPass123"; flow.reset.state.passwordConfirmation = "newPass123"
        await flow.reset.submit()
        XCTAssertTrue(flow.reset.state.didUpdatePassword)
        flow.open(.login)
        XCTAssertFalse(flow.login.state.didSignIn)
        flow.login.state.password = "newPass123"
        await flow.login.submit()
        XCTAssertEqual(f.auth.signInCount, 2)
        XCTAssertNotNil(flow.session.patient)
    }

    func testPasswordChangedButSignOutFailedRetriesOnlySignOut() async {
        let f = AuthFixture(); var repositories = f.repositories; repositories.callbacks = TestCallbacks(auth: f.auth)
        let vm = PasswordResetViewModel(repositories: repositories, session: f.session, configuration: config)
        _ = await vm.acceptRecoveryURL(config.redirectURL!)
        vm.state.newPassword = "newPass123"; vm.state.passwordConfirmation = "newPass123"
        f.auth.failSignOut = true
        await vm.submit()
        XCTAssertTrue(vm.state.needsSessionCleanup); XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertEqual(f.auth.updateCount, 1)
        f.auth.failSignOut = false
        await vm.submit()
        XCTAssertTrue(vm.state.didUpdatePassword); XCTAssertEqual(f.auth.updateCount, 1)
    }

    func testRecoveryCallbackFailureDoesNotAuthorizePasswordChange() async {
        let f = AuthFixture(); let callback = TestCallbacks(auth: f.auth); callback.shouldFail = true
        var repositories = f.repositories; repositories.callbacks = callback
        let vm = PasswordResetViewModel(repositories: repositories, session: f.session, configuration: config)
        let result = await vm.acceptRecoveryURL(config.redirectURL!)
        XCTAssertFalse(result); XCTAssertFalse(vm.state.isRecoveryReady)
        XCTAssertFalse(f.auth.signedIn); XCTAssertNotNil(vm.state.errorMessage)
    }
}
