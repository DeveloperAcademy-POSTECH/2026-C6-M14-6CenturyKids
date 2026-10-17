import XCTest
import ToDocDomain
@testable import ToDocFeatures

final class TestCallbacks: AuthCallbackRepository {
    let auth: TestAuthRepository
    var calls = 0
    var shouldFail = false
    var beforeRecovery: (() async -> Void)?
    init(auth: TestAuthRepository) { self.auth = auth }
    func recoverPasswordSession(from url: URL) async throws -> UUID {
        calls += 1
        await beforeRecovery?()
        if shouldFail { throw AuthFlowError("만료됨") }
        auth.signedIn = true; return auth.id
    }
}

@MainActor final class SignupResetTests: XCTestCase {
    let configuration = AuthConfiguration(terms: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 전용 약관") }), termsVersion: "test-v1", redirectURL: URL(string: "todoc-test://auth/callback"))
    func ready(_ vm: SignupViewModel) {
        let s = vm.state
        s.step = .review; s.name = "테스트"; s.email = "patient@example.com"
        s.password = "password123"; s.passwordConfirmation = s.password
        s.birthday = Date(timeIntervalSince1970: 946684800); s.sex = .female
        s.cancerType = .lung; s.stage = .known(.stage1)
        s.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
    }
    func testSignupRequiresConfiguredTermsBeforeCreatingAccount() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        ready(vm); await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertNotEqual(vm.state.step, .completion)
    }
    func testSignupRequiresProfileAndConsentRepositoriesBeforeCreatingAccount() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: .init(auth: f.auth), session: f.session, configuration: configuration)
        ready(vm); await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testSignupSavesSameIDAndConsentThenSignsOutBeforeCompletion() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.users.value?.id, f.auth.id); XCTAssertEqual(f.patients.value?.user.id, f.auth.id)
        XCTAssertEqual(Set(f.consents.saved), Set(["service", "privacy", "sensitiveInformation"]))
        XCTAssertFalse(f.auth.signedIn); XCTAssertNil(f.session.patient)
        XCTAssertEqual(vm.state.password, "")
    }
    func testSignupAcceptsDateOnlyBirthdayReturnedByRepository() async {
        let f = AuthFixture(); f.users.normalizeBirthday = true
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm)
        vm.state.birthday = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 946684800)).addingTimeInterval(13 * 3600)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
    }
    func testPartialSignupRetryDoesNotCreateAnotherAccountOrRepeatSuccessfulSaves() async {
        let f = AuthFixture(); f.patients.failNextSave = true
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); await vm.submit()
        XCTAssertNotEqual(vm.state.step, .completion); XCTAssertTrue(vm.state.isAccountLocked)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1); XCTAssertEqual(f.users.saves, 1); XCTAssertEqual(f.consents.saves, 1)
        XCTAssertEqual(f.patients.saves, 2)
    }
    func testEmailConfirmationIsNotSignupCompletionAndRetryUsesSignIn() async {
        let f = AuthFixture(); f.auth.confirmEmail = true
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); await vm.submit()
        XCTAssertTrue(vm.state.isAwaitingEmailConfirmation); XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 1); XCTAssertEqual(f.auth.signInCount, 1)
        XCTAssertEqual(vm.state.step, .completion)
    }
    func testUncertainAccountCreationNeverBlindlyRepeatsSignUp() async {
        let f = AuthFixture(); f.auth.failSignUp = true
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); await vm.submit(); await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 1); XCTAssertEqual(f.auth.signInCount, 1)
        XCTAssertEqual(vm.state.step, .completion)
    }
    func testCancelledSignupRemembersAccountForRetryWithoutShowingCompletion() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); f.auth.beforeSignUp = { vm.cancel() }
        await vm.submit()
        XCTAssertNotEqual(vm.state.step, .completion); XCTAssertFalse(f.auth.signedIn)
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 1); XCTAssertEqual(vm.state.step, .completion)
    }
    func testUnsupportedDiagnosisNeverInventsDatabaseValue() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); vm.state.stage = .unknown; await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testDoctorRoleCannotProceedIntoPatientSignup() {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.isPatient = false; vm.handle(.next)
        XCTAssertEqual(vm.state.step, .role); XCTAssertNotNil(vm.state.currentValidationError)
    }
    func testMissingDoctorRepositoryCanBeSkipped() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.step = .doctorCode; vm.state.doctorCode = "ABC123"
        await vm.verifyDoctorCode(); XCTAssertNotNil(vm.state.errorMessage)
        vm.handle(.skipDoctorCode)
        XCTAssertEqual(vm.state.step, .patientInfo); XCTAssertNil(vm.state.connection)
    }
    func testResetMissingAddressDoesNotPretendToSendEmail() async {
        let f = AuthFixture(); let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        vm.state.email = "patient@example.com"; await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 0); XCTAssertFalse(vm.state.didSend); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testResetSendsConfiguredAddressWithoutClaimingPasswordChanged() async {
        let f = AuthFixture(); var repos = f.repositories; repos.callbacks = TestCallbacks(auth: f.auth)
        let vm = PasswordResetViewModel(repositories: repos, session: f.session, configuration: configuration)
        vm.state.email = "patient@example.com"; await vm.submit()
        XCTAssertTrue(vm.state.didSend); XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertEqual(f.auth.lastRedirect, configuration.redirectURL)
    }
    func testWrongCallbackAddressNeverReachesRepository() async {
        let f = AuthFixture(); let callback = TestCallbacks(auth: f.auth); var repos = f.repositories; repos.callbacks = callback
        let vm = PasswordResetViewModel(repositories: repos, session: f.session, configuration: configuration)
        let accepted = await vm.acceptRecoveryURL(URL(string: "other://auth/callback?token=secret")!)
        XCTAssertFalse(accepted); XCTAssertEqual(callback.calls, 0); XCTAssertFalse(vm.state.isRecoveryReady)
        XCTAssertNotNil(vm.state.errorMessage)
    }
    func testOrdinaryLoggedInSessionCannotUpdatePasswordWithoutRecovery() async {
        let f = AuthFixture(); f.auth.signedIn = true
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.newPassword = "newPass123"; vm.state.passwordConfirmation = "newPass123"
        await vm.submit(); XCTAssertEqual(f.auth.updateCount, 0)
    }
    func testVerifiedRecoveryCanChangePasswordAndRequiresFreshLogin() async {
        let f = AuthFixture(); var repos = f.repositories; repos.callbacks = TestCallbacks(auth: f.auth)
        let vm = PasswordResetViewModel(repositories: repos, session: f.session, configuration: configuration)
        let accepted = await vm.acceptRecoveryURL(configuration.redirectURL!)
        XCTAssertTrue(accepted)
        vm.state.newPassword = "newPass123"; vm.state.passwordConfirmation = "newPass123"
        await vm.submit()
        XCTAssertTrue(vm.state.didUpdatePassword); XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertFalse(f.auth.signedIn); XCTAssertEqual(vm.state.newPassword, "")
    }
}
