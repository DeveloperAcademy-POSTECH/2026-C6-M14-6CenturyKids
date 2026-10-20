import XCTest
@testable import ToDocAuth

@MainActor final class AuthFlowRegressionTests: XCTestCase {
    func testUnsupportedLinkCannotChangeRouteOrDestroyExistingLogin() async throws {
        let f = AuthFixture(); try f.addProfile()
        let flow = AuthFlowViewModel(repositories: f.repositories)
        flow.login.state.email = "patient@example.com"; flow.login.state.password = "password123"
        await flow.login.submit()
        XCTAssertEqual(flow.rootRoute, .patient)
        await flow.handleURL(URL(string: "todoc-test://auth/callback?type=recovery&code=unverified")!)
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertTrue(f.auth.signedIn)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertFalse(flow.reset.state.isRecoveryReady)
        XCTAssertNotNil(flow.linkMessage)
    }
    func testUnrecognizedSignupLinkCannotCreateAccountOrEnterHome() async {
        let f = AuthFixture(); let flow = AuthFlowViewModel(repositories: f.repositories)
        await flow.handleURL(URL(string: "todoc-test://auth/signup?code=unverified")!)
        XCTAssertEqual(flow.rootRoute, .authentication)
        XCTAssertNil(flow.session.patient)
        XCTAssertEqual(f.auth.signInCount, 0); XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertFalse(flow.reset.state.isRecoveryReady)
        XCTAssertNotNil(flow.linkMessage)
    }
    func testConfiguredResetStillCannotSendEmailWithoutVerifiedRecoverySupport() async {
        let f = AuthFixture()
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session,
            configuration: .init(redirectURL: URL(string: "todoc-test://auth/recovery")))
        vm.state.email = "patient@example.com"
        await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 0); XCTAssertFalse(vm.state.didSend)
        XCTAssertFalse(vm.state.didUpdatePassword); XCTAssertNotNil(vm.state.errorMessage)
    }
}
