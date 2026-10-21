import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SignupSubmissionTests: XCTestCase {
    private func ready(_ f: AuthFixture) -> SignupViewModel {
        let setup = SignupResetTests()
        var configuration = setup.configuration
        configuration.allowsSignupRequests = true
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        setup.ready(vm)
        return vm
    }

    private func createAccount(_ vm: SignupViewModel) async {
        vm.state.step = .terms
        await vm.continueFromTerms()
        if vm.state.step == .patientInfo { vm.state.step = .review }
    }

    func testAccountIsCreatedBeforeAnyProfileInputOrSave() async {
        let f = AuthFixture(), vm = ready(f)
        vm.state.name = ""; vm.state.birthday = nil; vm.state.sex = nil
        vm.state.cancerType = nil; vm.state.stage = nil; vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(vm.state.step, .patientInfo)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertTrue(vm.state.password.isEmpty)
        XCTAssertFalse(vm.state.isAccountLocked)
        vm.handle(.back); vm.handle(.back)
        XCTAssertEqual(vm.state.step, .terms, "생성한 계정의 이메일·비밀번호 수정 단계로 돌아가지 않습니다.")
        await vm.continueFromTerms()
        XCTAssertEqual(f.auth.signUpCount, 1)
    }

    func testEarlyRequestRejectsInvalidEmailPasswordConfirmationAndRole() async {
        for invalidField in 0..<4 {
            let f = AuthFixture(), vm = ready(f)
            switch invalidField {
            case 0: vm.state.email = "invalid"
            case 1: vm.state.password = "short"
            case 2: vm.state.passwordConfirmation = "different"
            default: vm.state.isPatient = false
            }
            await createAccount(vm)
            XCTAssertEqual(f.auth.signUpCount, 0)
            XCTAssertFalse(vm.state.isAccountLocked)
            XCTAssertNotNil(vm.state.errorMessage)
        }
    }

    func testFinalSubmitRechecksTermsAndDiagnosisWithoutCreatingAccountAgain() async {
        for invalidTerms in [true, false] {
            let f = AuthFixture(), vm = ready(f)
            await createAccount(vm)
            if invalidTerms { vm.state.acceptedTerms = [] }
            else { vm.state.stage = nil }
            await vm.submit()
            XCTAssertEqual(f.auth.signUpCount, 1)
            XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
            XCTAssertNotNil(vm.state.errorMessage)
        }
    }

    func testSessionIdentityChangeAfterInputCannotSaveProfile() async {
        let f = AuthFixture(), vm = ready(f)
        await createAccount(vm)
        f.auth.currentUserResponseID = UUID()
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNil(vm.completedPatient)
    }

    func testCompletesAfterPatientReadBackAndKeepsSession() async {
        let f = AuthFixture(), vm = ready(f)
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.users.value?.id, f.auth.id)
        XCTAssertEqual(f.patients.value?.user.id, f.auth.id)
        XCTAssertEqual(f.patients.value?.disease?.carcinoma, .lung)
        XCTAssertEqual(f.patients.value?.disease?.stage, .stage1)
        XCTAssertTrue(f.auth.signedIn)
        XCTAssertNil(f.session.patient)
        XCTAssertEqual(vm.completedPatient?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertEqual(f.users.finds, 1)
        XCTAssertFalse(f.session.loginPreference.isEnabled)
        XCTAssertTrue(vm.state.password.isEmpty)
    }

    func testConfirmationWaitsAndContinuesWithoutCreatingAnotherAccount() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.confirmEmail = true
        await createAccount(vm)
        XCTAssertTrue(vm.state.isAwaitingEmailConfirmation)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.auth.signInCount, 0)
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.auth.signInCount, 1)
    }

    func testUnknownAccountCreationOutcomeNeverAutomaticallyRepeatsSignup() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.failSignUp = true
        await createAccount(vm)
        await createAccount(vm)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertTrue(vm.state.isAccountLocked)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testLostUserSaveResponseReusesSavedProfileOnRetry() async {
        let f = AuthFixture(), vm = ready(f)
        f.users.loseNextSaveResponse = true
        await createAccount(vm)
        await vm.submit()
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 1)
        XCTAssertEqual(f.patients.saves, 1)
    }

    func testPatientSaveFailureRetriesOnlyMissingProfile() async {
        let f = AuthFixture(), vm = ready(f)
        f.patients.failNextSave = true
        await createAccount(vm)
        await vm.submit()
        XCTAssertNotEqual(vm.state.step, .completion)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 1)
        XCTAssertEqual(f.patients.saves, 2)
    }

    func testExistingDifferentUserIsNeverOverwritten() async throws {
        let f = AuthFixture(), vm = ready(f)
        f.users.value = try User(id: f.auth.id, name: "다른 이름", birthday: Date(timeIntervalSince1970: 946684800), sex: .female)
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(f.users.value?.name, "다른 이름")
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testExistingIncompletePatientIsNotSilentlyFilledIn() async throws {
        let f = AuthFixture(), vm = ready(f)
        try f.addProfile()
        await createAccount(vm)
        await vm.submit()
        XCTAssertNil(f.patients.value?.disease)
        XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testCurrentIdentityMustMatchCreatedAccountBeforeWriting() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.currentUserResponseID = UUID()
        await createAccount(vm)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertTrue(f.auth.signedIn)
    }

    func testConfirmationSignInCannotAttachProfileToAnotherAccount() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.confirmEmail = true
        await createAccount(vm)
        f.auth.signInResponseID = UUID()
        await createAccount(vm)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testFinalSubmitWithoutAuthenticatedAccountCannotWriteProfiles() async {
        let f = AuthFixture(), vm = ready(f)
        XCTAssertFalse(vm.state.hasAuthenticatedAccount)
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertEqual(vm.state.step, .review)
        XCTAssertNil(vm.completedPatient)
        XCTAssertFalse(vm.state.isAccountLocked)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testDateOnlyBirthdayReadBackIsAccepted() async {
        let f = AuthFixture(), vm = ready(f)
        f.users.normalizeBirthday = true
        vm.state.birthday = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 946684800)).addingTimeInterval(43200)
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
    }

    func testCancellationAfterAccountCreationDoesNotWriteOrForgetItsIdentity() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.beforeSignUp = { vm.cancel() }
        await createAccount(vm)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertTrue(f.auth.signedIn)
        XCTAssertFalse(f.session.isBusy)
        f.auth.beforeSignUp = nil
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
    }

    func testCompletionDoesNotDependOnLogoutAndStartsAppWithVerifiedPatient() async {
        let f = AuthFixture()
        var configuration = SignupResetTests().configuration
        configuration.allowsSignupRequests = true
        let flow = AuthFlowViewModel(repositories: f.repositories, configuration: configuration)
        SignupResetTests().ready(flow.signup)
        f.auth.failSignOut = true
        await createAccount(flow.signup)
        await flow.signup.submit()
        XCTAssertEqual(flow.signup.state.step, .completion)
        XCTAssertEqual(flow.rootRoute, .authentication)
        flow.loginAfterSignup()
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertEqual(flow.session.patient?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertEqual(f.auth.signInCount, 0)
    }

    func testOrdinarySignupUsesDefaultConfigurationAndVerifiesSavedPatientBeforeOpeningApp() async {
        let f = AuthFixture(), flow = AuthFlowViewModel(repositories: f.repositories)
        flow.open(.signup)
        XCTAssertEqual(flow.screen, .signup)
        XCTAssertEqual(flow.signup.configuration.terms.count, 5)
        let s = flow.signup.state
        s.email = "patient@example.com"; s.password = "password123"; s.passwordConfirmation = s.password
        s.step = .passwordConfirmation
        flow.signup.handle(.next)
        XCTAssertEqual(s.step, .terms)
        await flow.signup.continueFromTerms()
        XCTAssertEqual(s.step, .terms)
        XCTAssertNotNil(s.errorMessage)
        XCTAssertEqual(f.auth.signUpCount, 0)
        s.acceptedTerms = Set(SignupTerm.allCases)
        await flow.signup.continueFromTerms()
        XCTAssertEqual(s.step, .patientInfo)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertTrue(s.password.isEmpty)
        flow.signup.handle(.back)
        XCTAssertEqual(s.step, .terms)
        await flow.signup.continueFromTerms()
        XCTAssertEqual(s.step, .patientInfo)
        s.name = "테스트"; s.birthday = Date(timeIntervalSince1970: 946684800); s.sex = .female
        s.cancerType = .lung; s.stage = .known(.stage1)
        s.step = .review
        await flow.signup.submit()
        XCTAssertEqual(s.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 1); XCTAssertEqual(f.patients.saves, 1)
        XCTAssertEqual(s.acceptedTerms.count, 5)
        XCTAssertEqual(flow.signup.completedPatient?.user.id, f.auth.id)
        XCTAssertEqual(flow.rootRoute, .authentication)
        flow.loginAfterSignup()
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertEqual(flow.session.patient?.user.id, f.auth.id)
    }

    func testExpiredCreatedAccountNeverSignsInWithClearedPasswordOrCreatesAnotherAccount() async {
        let f = AuthFixture(), vm = ready(f)
        await createAccount(vm)
        XCTAssertTrue(vm.state.password.isEmpty)
        f.auth.signedIn = false
        vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(f.auth.signInCount, 0)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertEqual(vm.state.step, .terms)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testAllFiveTermsGateAccountCreationBeforeProfileInput() async {
        let f = AuthFixture(), vm = ready(f)
        vm.state.step = .terms
        vm.state.acceptedTerms = [.service, .privacy, .sensitiveInformation, .doctorConnection]
        XCTAssertFalse(vm.state.canProceedFromTerms)
        await vm.continueFromTerms()
        XCTAssertEqual(f.auth.signUpCount, 0)
        vm.state.acceptedTerms.insert(.thirdPartyProvision)
        XCTAssertTrue(vm.state.canProceedFromTerms)
        await vm.continueFromTerms()
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(vm.state.step, .patientInfo)
        XCTAssertEqual(vm.state.acceptedTerms.count, 5)
    }

    func testExistingLoginIsNotChangedByStartingAnotherSignup() async throws {
        let f = AuthFixture(), vm = ready(f)
        f.auth.signedIn = true
        try f.addProfile()
        f.session.patient = f.patients.value
        f.session.loginPreference.isEnabled = true
        await createAccount(vm)
        XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertNotNil(f.session.patient)
        XCTAssertTrue(f.session.loginPreference.isEnabled)
    }

    func testBusySessionDoesNotFreezeInputsBeforeSignupActuallyStarts() async throws {
        let f = AuthFixture(), vm = ready(f)
        let otherRequest = try XCTUnwrap(f.session.begin())
        await createAccount(vm)
        XCTAssertFalse(vm.state.isAccountLocked)
        vm.state.email = "corrected@example.com"
        f.session.finish(otherRequest)
        await createAccount(vm)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(vm.state.email, "corrected@example.com")
    }

    func testUnknownDiagnosisSurvivesProfileSaveReadBackAndNewLogin() async {
        let combinations: [(CarcinomaType, SignupStageChoice, CarcinomaStage)] = [
            (.unknown, .known(.stage3), .stage3),
            (.lung, .unknown, .unknown),
            (.unknown, .unknown, .unknown)
        ]
        for (cancer, choice, stage) in combinations {
            let f = AuthFixture(), vm = ready(f)
            vm.state.cancerType = cancer; vm.state.stage = choice
            await createAccount(vm)
            await vm.submit()
            XCTAssertEqual(vm.state.step, .completion)
            XCTAssertEqual(vm.completedPatient?.disease?.carcinoma, cancer)
            XCTAssertEqual(vm.completedPatient?.disease?.stage, stage)
            XCTAssertEqual(f.patients.saves, 1)

            let newSession = AuthSessionState()
            let login = LoginViewModel(repositories: f.repositories, session: newSession)
            login.state.email = "patient@example.com"; login.state.password = "password123"
            await login.submit()
            XCTAssertTrue(login.state.didSignIn)
            XCTAssertEqual(newSession.patient?.disease?.carcinoma, cancer)
            XCTAssertEqual(newSession.patient?.disease?.stage, stage)
            XCTAssertEqual(f.auth.signUpCount, 1)
            XCTAssertEqual(f.users.finds, 1, "로그인에서는 Patient.findById만 사용합니다.")
        }
    }
}
