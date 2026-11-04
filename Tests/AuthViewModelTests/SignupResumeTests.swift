import XCTest
import ToDocDomain
@testable import ToDocAuth

private final class ResumeDoctors: DoctorRepository {
    var value: Doctor?
    var error: Error?
    var beforeFind: (() async -> Void)?
    func findById(_ id: UUID) async throws -> Doctor? {
        await beforeFind?()
        if let error { throw error }
        return value
    }
    func save(doctor: Doctor) async throws { XCTFail("재개 중 의사를 저장하면 안 됩니다.") }
    func findByName(_ name: String) async throws -> [Doctor] { [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { [] }
    func findByCode(_ code: String) async throws -> Doctor? { nil }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? {
        XCTFail("가입 재개는 의사 코드를 조회하지 않습니다."); return nil
    }
}

@MainActor final class SignupResumeTests: XCTestCase {
    private func flow(_ f: AuthFixture, doctors: ResumeDoctors? = ResumeDoctors(),
                      configuration: AuthConfiguration = .init()) -> AuthFlowViewModel {
        var repositories = f.repositories
        repositories.doctors = doctors
        return AuthFlowViewModel(repositories: repositories, configuration: configuration, session: AuthSessionState())
    }
    private func login(_ flow: AuthFlowViewModel) async {
        flow.open(.login)
        flow.login.state.email = "  patient@example.com  "
        flow.login.state.password = "existingPassword"
        await flow.login.submit()
    }
    private func acceptTerms(_ flow: AuthFlowViewModel) async {
        flow.signup.state.acceptedTerms = Set(SignupTerm.allCases)
        await flow.signup.continueFromTerms()
    }
    private func fillMissingProfile(_ flow: AuthFlowViewModel) {
        let state = flow.signup.state
        if !state.hasStoredUserProfile {
            state.name = "테스트"; state.birthday = Date(timeIntervalSince1970: 946684800); state.sex = .female
        }
        state.cancerType = .lung; state.stage = .known(.stage1); state.step = .review
    }

    func testAppRestartAfterAccountCreationCanFinishThroughLoginWithoutAnotherSignup() async {
        let f = AuthFixture()
        var configuration = AuthConfiguration(); configuration.allowsSignupRequests = true
        var first: AuthFlowViewModel? = AuthFlowViewModel(repositories: f.repositories, configuration: configuration, session: AuthSessionState())
        let state = first!.signup.state
        state.email = "patient@example.com"; state.password = "password123"; state.passwordConfirmation = state.password
        state.acceptedTerms = Set(SignupTerm.allCases); state.step = .terms
        await first!.signup.continueFromTerms()
        XCTAssertEqual(state.step, .patientInfo)
        XCTAssertEqual(f.auth.signUpCount, 1)
        first = nil

        var resumeConfiguration = AuthConfiguration(); resumeConfiguration.allowsSignupRequests = false
        let resumed = flow(f, configuration: resumeConfiguration)
        await resumed.restoreSessionOnce()
        await login(resumed)
        XCTAssertEqual(resumed.screen, .signup)
        XCTAssertEqual(resumed.signup.state.step, .terms)
        XCTAssertTrue(resumed.signup.state.acceptedTerms.isEmpty)
        XCTAssertTrue(resumed.login.state.password.isEmpty)
        XCTAssertFalse(resumed.session.loginPreference.isEnabled)
        XCTAssertEqual(resumed.rootRoute, .authentication)
        XCTAssertFalse(resumed.signup.configuration.allowsSignupRequests)
        await acceptTerms(resumed)
        XCTAssertEqual(resumed.signup.state.step, .patientInfo)
        fillMissingProfile(resumed)
        await resumed.signup.submit()
        XCTAssertEqual(resumed.signup.state.step, .completion)
        XCTAssertEqual(f.users.value?.id, f.auth.id)
        XCTAssertEqual(f.patients.value?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.signUpCount, 1)
        resumed.loginAfterSignup()
        XCTAssertEqual(resumed.rootRoute, .patient)
    }

    func testMissingAgreementWaitsInsteadOfBypassingTermsOnResume() async {
        let configuration = AuthConfiguration()
        let f = AuthFixture(), resumed = AuthFlowViewModel(repositories: f.repositories, configuration: configuration, session: AuthSessionState())
        await login(resumed)
        resumed.signup.state.acceptedTerms = Set(SignupTerm.allCases).subtracting([.appUsage])
        XCTAssertFalse(resumed.signup.state.canProceedFromTerms)
        await resumed.signup.continueFromTerms()
        XCTAssertEqual(resumed.signup.state.step, .terms)
        XCTAssertNotNil(resumed.signup.state.errorMessage)
        XCTAssertEqual(f.users.finds, 0)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertEqual(f.auth.signUpCount, 0)
    }

    func testPartiallySavedUserIsLoadedAndOnlyPatientIsWritten() async throws {
        let f = AuthFixture(); try f.addProfile(); f.patients.value = nil
        let resumed = flow(f)
        await login(resumed)
        XCTAssertEqual(f.users.finds, 0, "로그인 자체는 Patient.findById만 사용합니다.")
        await acceptTerms(resumed)
        XCTAssertTrue(resumed.signup.state.hasStoredUserProfile)
        XCTAssertEqual(resumed.signup.state.name, f.users.value?.name)
        XCTAssertEqual(resumed.signup.state.birthday, f.users.value?.birthday)
        fillMissingProfile(resumed)
        await resumed.signup.submit()
        XCTAssertEqual(resumed.signup.state.step, .completion)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 1)
        XCTAssertEqual(f.auth.signUpCount, 0)
    }

    func testSavedUserCannotBeOverwrittenEvenIfInputsAreChangedProgrammatically() async throws {
        let f = AuthFixture(); try f.addProfile(); f.patients.value = nil
        let resumed = flow(f)
        await login(resumed); await acceptTerms(resumed)
        fillMissingProfile(resumed); resumed.signup.state.name = "바뀐 이름"
        await resumed.signup.submit()
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(resumed.signup.state.step, .completion)
    }

    func testPatientLookupErrorOrWrongIDDoesNotOpenResume() async throws {
        for wrongID in [false, true] {
            let f = AuthFixture()
            if wrongID { try f.addProfile(id: UUID()) }
            else { f.patients.findError = URLError(.timedOut) }
            let resumed = flow(f), original = resumed.signup
            await login(resumed)
            XCTAssertTrue(resumed.signup === original)
            XCTAssertEqual(resumed.screen, .login)
            XCTAssertNotNil(resumed.login.state.errorMessage)
            XCTAssertFalse(f.auth.signedIn)
            XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        }
    }

    func testCompletePatientUsesNormalLoginAndNeverReopensSignup() async throws {
        let f = AuthFixture(); try f.addProfile()
        let resumed = flow(f), original = resumed.signup
        await login(resumed)
        XCTAssertTrue(resumed.signup === original)
        XCTAssertEqual(resumed.rootRoute, .patient)
        XCTAssertEqual(f.users.finds, 0)
    }

    func testDoctorAccountAndFailedOrUnavailableRoleLookupCannotEnterPatientInput() async throws {
        for scenario in 0..<3 {
            let f = AuthFixture(), doctors = ResumeDoctors()
            if scenario == 0 {
                try f.addProfile(); f.patients.value = nil
                doctors.value = Doctor(user: f.users.value!, code: "ABC123", hospitalId: UUID())
            } else { doctors.error = URLError(.notConnectedToInternet) }
            let resumed = flow(f, doctors: scenario == 2 ? nil : doctors)
            await login(resumed); await acceptTerms(resumed)
            XCTAssertEqual(resumed.signup.state.step, .terms)
            XCTAssertNotNil(resumed.signup.state.errorMessage)
            fillMissingProfile(resumed); await resumed.signup.submit()
            XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
            XCTAssertEqual(f.auth.signUpCount, 0)
        }
    }

    func testExpiredSessionOrWrongIdentityCannotResume() async {
        for wrongID in [false, true] {
            let f = AuthFixture(), resumed = flow(f)
            await login(resumed)
            if wrongID { f.auth.currentUserResponseID = UUID() }
            else { f.auth.signedIn = false }
            await acceptTerms(resumed)
            XCTAssertEqual(resumed.signup.state.step, .terms)
            XCTAssertNotNil(resumed.signup.state.errorMessage)
            XCTAssertEqual(f.users.finds, 0)
            XCTAssertEqual(f.auth.signInCount, 1, "빈 비밀번호로 자동 로그인하지 않습니다.")
            XCTAssertEqual(f.auth.signUpCount, 0)
        }
    }

    func testWrongUserIDAndCancelledProfileReadCannotPublishInput() async throws {
        for cancel in [false, true] {
            let f = AuthFixture(), doctors = ResumeDoctors()
            try f.addProfile(id: UUID()); f.patients.value = nil
            let resumed = flow(f, doctors: doctors)
            await login(resumed)
            if cancel { doctors.beforeFind = { resumed.signup.cancel() } }
            await acceptTerms(resumed)
            XCTAssertEqual(resumed.signup.state.step, .terms)
            XCTAssertTrue(resumed.signup.state.name.isEmpty)
            XCTAssertFalse(resumed.session.isBusy)
            XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        }
    }

    func testFailedUserLookupCanRetryWithoutLosingSavedProfileOrCreatingAccount() async throws {
        let f = AuthFixture(); try f.addProfile(); f.patients.value = nil
        let resumed = flow(f)
        await login(resumed)
        f.users.findError = URLError(.timedOut)
        await acceptTerms(resumed)
        XCTAssertEqual(resumed.signup.state.step, .terms)
        XCTAssertFalse(resumed.signup.state.hasStoredUserProfile)
        f.users.findError = nil
        await acceptTerms(resumed)
        XCTAssertEqual(resumed.signup.state.step, .patientInfo)
        XCTAssertTrue(resumed.signup.state.hasStoredUserProfile)
        XCTAssertEqual(f.auth.signUpCount, 0)
    }

    func testCancellationDuringMissingPatientLookupDoesNotOpenResume() async {
        let f = AuthFixture(), resumed = flow(f)
        let original = resumed.signup
        f.patients.beforeFind = { resumed.login.cancel() }
        await login(resumed)
        XCTAssertTrue(resumed.signup === original)
        XCTAssertEqual(resumed.screen, .login)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertFalse(resumed.session.isBusy)
    }

    func testResumeRequiresNewAgreementBeforeLookupOrSave() async {
        let f = AuthFixture(), resumed = flow(f)
        await login(resumed)
        await resumed.signup.continueFromTerms()
        XCTAssertEqual(resumed.signup.state.errorMessage, "필수 약관에 동의해 주세요.")
        XCTAssertEqual(f.users.finds, 0)
        fillMissingProfile(resumed)
        await resumed.signup.submit()
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertEqual(f.auth.signUpCount, 0)
    }

    func testRestartAfterProfileSaveFailureReturnsToLoginInsteadOfCreatingAnotherAccount() async {
        let f = AuthFixture(), resumed = flow(f)
        await login(resumed); await acceptTerms(resumed)
        fillMissingProfile(resumed); f.patients.failNextSave = true
        await resumed.signup.submit()
        XCTAssertTrue(resumed.signup.state.isAccountLocked)
        resumed.restartSignupAfterConfirmation()
        XCTAssertEqual(resumed.screen, .login)
        await login(resumed); await acceptTerms(resumed)
        XCTAssertTrue(resumed.signup.state.hasStoredUserProfile)
        XCTAssertEqual(f.auth.signUpCount, 0)
    }

    func testReloginReplacesOldProfileAndAgreements() async {
        let f = AuthFixture(), resumed = flow(f)
        await login(resumed); await acceptTerms(resumed)
        let previous = resumed.signup
        previous.state.name = "이전 입력"
        previous.state.doctorCode = "ABC123"
        resumed.loginAfterSignup()
        f.auth.signInResponseID = UUID(); f.auth.currentUserResponseID = f.auth.signInResponseID
        await login(resumed)
        XCTAssertFalse(resumed.signup === previous)
        XCTAssertTrue(resumed.signup.state.name.isEmpty)
        XCTAssertTrue(resumed.signup.state.doctorCode.isEmpty)
        XCTAssertTrue(resumed.signup.state.acceptedTerms.isEmpty)
        XCTAssertTrue(resumed.signup.state.password.isEmpty)
        XCTAssertEqual(resumed.signup.state.email, "patient@example.com")
        XCTAssertEqual(f.auth.signUpCount, 0)
    }
}
