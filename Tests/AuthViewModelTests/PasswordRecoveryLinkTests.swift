import Foundation
import XCTest
@testable import ToDocAuth

@MainActor final class PasswordRecoveryLinkTests: XCTestCase {
    private let callback = URL(string: "todoc://auth/change-password?code=verified-by-sdk")!

    func testVerifiedCallbackOpensNewPasswordFormWithoutRestoringHome() async {
        let f = AuthFixture()
        let flow = AuthFlowViewModel(repositories: f.repositories, session: f.session)
        await flow.handleURL(callback)
        XCTAssertEqual(f.auth.recoveryCount, 1)
        XCTAssertEqual(flow.screen, .passwordReset)
        XCTAssertTrue(flow.showsAuth)
        XCTAssertTrue(flow.reset.state.isRecoveryReady)
        XCTAssertEqual(flow.rootRoute, .authentication)
        XCTAssertFalse(f.session.loginPreference.isEnabled)
        XCTAssertFalse(f.session.isBusy)
        XCTAssertNil(flow.linkMessage)
        XCTAssertEqual(f.auth.updateCount, 0)
    }

    func testMalformedCallbacksCannotUseAnExistingSessionAsRecoveryProof() async {
        let f = AuthFixture()
        f.auth.signedIn = true
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        for address in [
            "todoc://auth/change-password",
            "todoc://auth/change-password?type=recovery",
            "todoc://auth/change-password?code=",
            "todoc://auth/change-password?code=a&code=b",
            "todoc://auth/change-password?code=a&error=expired",
            "todoc://auth/change-password#access_token=unverified&type=recovery",
            "todoc://auth/recovery?code=a",
            "todoc://other/change-password?code=a",
            "https://auth/change-password?code=a"
        ] {
            let accepted = await vm.acceptRecoveryURL(URL(string: address)!)
            XCTAssertFalse(accepted, address)
            XCTAssertFalse(vm.state.isRecoveryReady, address)
        }
        XCTAssertEqual(f.auth.recoveryCount, 0)
        XCTAssertTrue(f.auth.signedIn)
    }

    func testFailedCodeExchangeKeepsExistingLoginAndDoesNotOpenForm() async throws {
        let f = AuthFixture()
        try f.addProfile()
        f.auth.signedIn = true
        f.session.loginPreference.isEnabled = true
        f.session.patient = f.patients.value
        f.auth.recoveryError = URLError(.userAuthenticationRequired)
        let flow = AuthFlowViewModel(repositories: f.repositories, session: f.session)
        await flow.handleURL(callback)
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertFalse(flow.reset.state.isRecoveryReady)
        XCTAssertNotNil(flow.linkMessage)
        XCTAssertTrue(f.session.loginPreference.isEnabled)
        XCTAssertEqual(f.auth.signOutCount, 0)
    }

    func testRecoveryCanReplaceExistingLoginWithoutPersistingIt() async throws {
        let f = AuthFixture()
        try f.addProfile()
        f.auth.signedIn = true
        f.session.loginPreference.isEnabled = true
        f.session.patient = f.patients.value
        let flow = AuthFlowViewModel(repositories: f.repositories, session: f.session)
        await flow.handleURL(callback)
        XCTAssertNil(f.session.patient)
        XCTAssertEqual(flow.screen, .passwordReset)
        XCTAssertTrue(flow.reset.state.isRecoveryReady)
        XCTAssertFalse(f.session.loginPreference.isEnabled)
    }

    func testCancelDuringExchangeDiscardsLateSession() async throws {
        let f = AuthFixture()
        try f.addProfile()
        f.session.patient = f.patients.value
        f.session.loginPreference.isEnabled = true
        f.auth.signedIn = true
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        var resume: CheckedContinuation<Void, Never>?
        f.auth.beforeRecovery = { await withCheckedContinuation { resume = $0 } }
        let task = Task { await vm.acceptRecoveryURL(callback) }
        while resume == nil { await Task.yield() }
        vm.cancel()
        resume?.resume()
        let accepted = await task.value
        XCTAssertFalse(accepted)
        XCTAssertFalse(vm.state.isRecoveryReady)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertEqual(f.auth.signOutCount, 1)
        XCTAssertNil(f.session.patient)
        XCTAssertFalse(f.session.loginPreference.isEnabled)
        XCTAssertFalse(f.session.isBusy)
    }

    func testLeavingRecoveryFormSignsOutRecoverySession() async {
        let f = AuthFixture()
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        let accepted = await vm.acceptRecoveryURL(callback)
        XCTAssertTrue(accepted)
        vm.state.newPassword = "TemporaryPassword123!"
        vm.cancel()
        while f.session.isBusy { await Task.yield() }
        XCTAssertFalse(vm.state.isRecoveryReady)
        XCTAssertTrue(vm.state.newPassword.isEmpty)
        XCTAssertFalse(f.auth.signedIn)
    }
}
