import XCTest
@testable import ToDocAuth

@MainActor final class LoginOnboardingTests: XCTestCase {
    func testValidCredentialsNeedBothProfilesBeforeEnteringApp() async throws {
        let f = AuthFixture(); try f.addProfile()
        let vm = LoginViewModel(repositories: f.repositories, session: f.session)
        vm.state.email = "  patient@example.com  "; vm.state.password = "oldPassword"
        await vm.submit()
        XCTAssertTrue(vm.state.didSignIn)
        XCTAssertEqual(f.session.patient?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.lastEmail, "patient@example.com")
        XCTAssertEqual(vm.state.password, "")
    }
    func testMissingRepositoriesDoNotSendCredentials() async {
        let f = AuthFixture()
        let vm = LoginViewModel(repositories: .init(auth: f.auth), session: f.session)
        vm.state.email = "patient@example.com"; vm.state.password = "password"
        await vm.submit()
        XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertEqual(f.auth.signInCount, 0)
        XCTAssertFalse(vm.state.didSignIn)
    }
    func testInvalidInputDoesNotCallRepository() async {
        let f = AuthFixture(); let vm = LoginViewModel(repositories: f.repositories, session: f.session)
        vm.state.email = "broken"
        await vm.submit()
        XCTAssertNotNil(vm.state.emailError); XCTAssertNotNil(vm.state.passwordError)
        XCTAssertEqual(f.auth.signInCount, 0)
    }
    func testWrongProfileIDNeverEntersAppAndClearsSDKSession() async throws {
        let f = AuthFixture(); try f.addProfile(id: UUID())
        let vm = LoginViewModel(repositories: f.repositories, session: f.session)
        vm.state.email = "patient@example.com"; vm.state.password = "password"
        await vm.submit()
        XCTAssertFalse(vm.state.didSignIn); XCTAssertNil(f.session.patient)
        XCTAssertFalse(f.auth.signedIn); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testCancelIgnoresLateLoginAndBlocksCompetingRequestUntilSettled() async throws {
        let f = AuthFixture(); try f.addProfile()
        let vm = LoginViewModel(repositories: f.repositories, session: f.session)
        vm.state.email = "patient@example.com"; vm.state.password = "password"
        f.auth.beforeSignIn = {
            vm.cancel()
            XCTAssertTrue(f.session.isBusy)
            await vm.submit()
        }
        await vm.submit()
        XCTAssertEqual(f.auth.signInCount, 1)
        XCTAssertFalse(vm.state.didSignIn); XCTAssertNil(f.session.patient)
        XCTAssertFalse(f.auth.signedIn); XCTAssertFalse(f.session.isBusy)
    }
    func testOnboardingRestoresVerifiedPatientOnly() async throws {
        let f = AuthFixture(); try f.addProfile(); f.auth.signedIn = true; f.session.loginPreference.isEnabled = true
        let vm = OnboardingViewModel(repositories: f.repositories, session: f.session)
        await vm.restoreSession()
        XCTAssertEqual(f.session.patient?.user.id, f.auth.id)
        XCTAssertFalse(vm.isRestoring)
    }
    func testOnboardingMissingPatientDoesNotOpenHome() async {
        let f = AuthFixture(); f.auth.signedIn = true; f.session.loginPreference.isEnabled = true
        let vm = OnboardingViewModel(repositories: f.repositories, session: f.session)
        await vm.restoreSession()
        XCTAssertNil(f.session.patient); XCTAssertNotNil(vm.errorMessage)
    }
    func testIntroPageIsClampedToExistingPages() {
        let f = AuthFixture(); let vm = OnboardingViewModel(repositories: f.repositories, session: f.session)
        vm.selectPage(7); XCTAssertEqual(vm.page, 4)
        vm.selectPage(-1); XCTAssertEqual(vm.page, 0)
    }
}
