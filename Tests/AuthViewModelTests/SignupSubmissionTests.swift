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

    func testCompletesOnlyAfterProfilesAreReadBackAndSessionIsClosed() async {
        let f = AuthFixture(), vm = ready(f)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.users.value?.id, f.auth.id)
        XCTAssertEqual(f.patients.value?.user.id, f.auth.id)
        XCTAssertEqual(f.patients.value?.disease?.carcinoma, .lung)
        XCTAssertEqual(f.patients.value?.disease?.stage, .stage1)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertNil(f.session.patient)
        XCTAssertFalse(f.session.loginPreference.isEnabled)
        XCTAssertTrue(vm.state.password.isEmpty)
    }

    func testConfirmationWaitsAndContinuesWithoutCreatingAnotherAccount() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.confirmEmail = true
        await vm.submit()
        XCTAssertTrue(vm.state.isAwaitingEmailConfirmation)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.auth.signInCount, 0)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.auth.signInCount, 1)
    }

    func testUnknownAccountCreationOutcomeNeverAutomaticallyRepeatsSignup() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.failSignUp = true
        await vm.submit()
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertTrue(vm.state.isAccountLocked)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testLostUserSaveResponseReusesSavedProfileOnRetry() async {
        let f = AuthFixture(), vm = ready(f)
        f.users.loseNextSaveResponse = true
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
        await vm.submit()
        XCTAssertEqual(f.users.value?.name, "다른 이름")
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testExistingIncompletePatientIsNotSilentlyFilledIn() async throws {
        let f = AuthFixture(), vm = ready(f)
        try f.addProfile()
        await vm.submit()
        XCTAssertNil(f.patients.value?.disease)
        XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testCurrentIdentityMustMatchCreatedAccountBeforeWriting() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.currentUserResponseID = UUID()
        await vm.submit()
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertFalse(f.auth.signedIn)
    }

    func testConfirmationSignInCannotAttachProfileToAnotherAccount() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.confirmEmail = true
        await vm.submit()
        f.auth.signInResponseID = UUID()
        await vm.submit()
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testInvalidFinalInputCannotCreateAnAccountEvenWhenEnabled() async {
        let f = AuthFixture(), vm = ready(f)
        vm.state.stage = .unknown
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertFalse(vm.state.isAccountLocked)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testDateOnlyBirthdayReadBackIsAccepted() async {
        let f = AuthFixture(), vm = ready(f)
        f.users.normalizeBirthday = true
        vm.state.birthday = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 946684800)).addingTimeInterval(43200)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
    }

    func testCancellationAfterAccountCreationDoesNotWriteOrForgetItsIdentity() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.beforeSignUp = { vm.cancel() }
        await vm.submit()
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertFalse(f.session.isBusy)
        f.auth.beforeSignUp = nil
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
    }

    func testSignOutFailureDoesNotReportCompletionOrRepeatWrites() async {
        let f = AuthFixture(), vm = ready(f)
        f.auth.failSignOut = true
        await vm.submit()
        XCTAssertNotEqual(vm.state.step, .completion)
        f.auth.failSignOut = false
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.auth.signUpCount, 1)
        XCTAssertEqual(f.users.saves, 1)
        XCTAssertEqual(f.patients.saves, 1)
    }

    func testExistingLoginIsNotChangedByStartingAnotherSignup() async throws {
        let f = AuthFixture(), vm = ready(f)
        f.auth.signedIn = true
        try f.addProfile()
        f.session.patient = f.patients.value
        f.session.loginPreference.isEnabled = true
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertNotNil(f.session.patient)
        XCTAssertTrue(f.session.loginPreference.isEnabled)
    }

    func testBusySessionDoesNotFreezeInputsBeforeSignupActuallyStarts() async throws {
        let f = AuthFixture(), vm = ready(f)
        let otherRequest = try XCTUnwrap(f.session.begin())
        await vm.submit()
        XCTAssertFalse(vm.state.isAccountLocked)
        vm.state.email = "corrected@example.com"
        f.session.finish(otherRequest)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(vm.state.email, "corrected@example.com")
    }
}
