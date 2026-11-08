import AuthenticationServices
import XCTest
@testable import ToDocAuth

@MainActor final class AccountWithdrawalViewModelTests: XCTestCase {
    func testInjectedSessionIsSharedByAuthFlowAndWithdrawal() async throws {
        let fixture = AuthFixture()
        try fixture.addProfile()
        let flow = AuthFlowViewModel(repositories: fixture.repositories, session: fixture.session)
        XCTAssertTrue(flow.session === fixture.session)
        XCTAssertTrue(flow.login.session === fixture.session)
        XCTAssertTrue(flow.signup.session === fixture.session)
        XCTAssertTrue(flow.reset.session === fixture.session)
        XCTAssertTrue(flow.onboarding.session === fixture.session)
        flow.login.state.email = "patient@example.com"
        flow.login.state.password = "password"
        await flow.login.submit()
        XCTAssertEqual(flow.rootRoute, .patient)
        let withdrawal = AccountWithdrawalViewModel(authRepository: WithdrawalAuthDouble(), authSession: fixture.session)
        await withdrawal.withdrawAppleAccount(authorizationCode: "code")
        XCTAssertEqual(flow.rootRoute, .authentication)
        XCTAssertNil(flow.session.patient)
        XCTAssertFalse(flow.session.loginPreference.isEnabled)
    }

    func testEmailWithdrawalReauthenticatesBeforeDeletion() async {
        let auth = WithdrawalAuthDouble()
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        model.password = "password"
        await model.withdrawEmailAccount()
        XCTAssertEqual(auth.calls, ["id", "email", "signIn", "delete"])
        XCTAssertTrue(model.didWithdraw)
        XCTAssertEqual(model.password, "")
        XCTAssertFalse(model.isWithdrawing)
    }

    func testBothWithdrawalMethodsClearSharedSessionAfterSuccess() async throws {
        for usesApple in [false, true] {
            let fixture = AuthFixture()
            try fixture.addProfile()
            fixture.session.patient = fixture.patients.value
            fixture.session.loginPreference.isEnabled = true
            let auth = WithdrawalAuthDouble()
            let model = AccountWithdrawalViewModel(authRepository: auth, authSession: fixture.session)
            model.password = "password"
            if usesApple {
                await model.withdrawAppleAccount(authorizationCode: "code")
            } else {
                await model.withdrawEmailAccount()
            }
            XCTAssertTrue(model.didWithdraw)
            XCTAssertNil(fixture.session.patient)
            XCTAssertFalse(fixture.session.loginPreference.isEnabled)
        }
    }

    func testFailedWithdrawalPreservesSharedSession() async throws {
        let fixture = AuthFixture()
        try fixture.addProfile()
        fixture.session.patient = fixture.patients.value
        fixture.session.loginPreference.isEnabled = true
        let auth = WithdrawalAuthDouble()
        auth.failsDeletion = true
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: fixture.session)
        model.password = "password"
        await model.withdrawEmailAccount()
        XCTAssertFalse(model.didWithdraw)
        XCTAssertEqual(fixture.session.patient?.user.id, fixture.auth.id)
        XCTAssertTrue(fixture.session.loginPreference.isEnabled)
    }

    func testDifferentReauthenticatedAccountCannotBeDeleted() async {
        let auth = WithdrawalAuthDouble()
        auth.verifiedID = UUID()
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        model.password = "password"
        await model.withdrawEmailAccount()
        XCTAssertFalse(auth.calls.contains("delete"))
        XCTAssertFalse(model.didWithdraw)
        XCTAssertNotNil(model.errorMessage)
    }

    func testDeletionFailureKeepsScreenAvailableForRetry() async {
        let auth = WithdrawalAuthDouble()
        auth.failsDeletion = true
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        model.password = "password"
        await model.withdrawEmailAccount()
        XCTAssertFalse(model.didWithdraw)
        XCTAssertFalse(model.isWithdrawing)
        XCTAssertNotNil(model.errorMessage)
        auth.failsDeletion = false
        await model.withdrawEmailAccount()
        XCTAssertTrue(model.didWithdraw)
        XCTAssertNil(model.errorMessage)
    }

    func testAppleWithdrawalCompletesOnlyOnce() async {
        let auth = WithdrawalAuthDouble()
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        await model.withdrawAppleAccount(authorizationCode: "code")
        await model.withdrawAppleAccount(authorizationCode: "code")
        XCTAssertEqual(auth.calls, ["apple"])
        XCTAssertTrue(model.didWithdraw)
    }

    func testAppleCancellationDoesNotDeleteOrShowError() async {
        let auth = WithdrawalAuthDouble()
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        await model.handleAppleAuthorization(.failure(ASAuthorizationError(.canceled)))
        XCTAssertTrue(auth.calls.isEmpty)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.didWithdraw)
    }

    func testMissingEmailCannotDeleteAccount() async {
        let auth = WithdrawalAuthDouble()
        auth.email = nil
        let model = AccountWithdrawalViewModel(authRepository: auth, authSession: AuthSessionState())
        model.password = "password"
        await model.withdrawEmailAccount()
        XCTAssertEqual(auth.calls, ["id", "email"])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.didWithdraw)
    }
}

private final class WithdrawalAuthDouble: AuthRepository {
    struct Failure: Error {}
    let id = UUID()
    var verifiedID: UUID?
    var email: String? = "test@example.com"
    var failsDeletion = false
    var calls: [String] = []
    func getCurrentUserId() async throws -> UUID { calls.append("id"); return id }
    func getCurrentUserEmail() async throws -> String? { calls.append("email"); return email }
    func signIn(email: String, password: String) async throws -> UUID { calls.append("signIn"); return verifiedID ?? id }
    func deleteAccount() async throws { calls.append("delete"); if failsDeletion { throw Failure() } }
    func withdrawAppleAccount(authorizationCode: String) async throws { calls.append("apple"); if failsDeletion { throw Failure() } }
    func signUp(email: String, password: String) async throws -> UUID { throw Failure() }
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws {}
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID { throw Failure() }
    func signInWithKakao(idToken: String) async throws -> UUID { throw Failure() }
    func signOut() async throws {}
    func isSignedIn() -> Bool { true }
    func requestPasswordChangeVerification() async throws {}
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws {}
    func updatePassword(to newPassword: String, nonce: String?) async throws {}
    func getSignUpProvider() async throws -> String? { nil }
}
