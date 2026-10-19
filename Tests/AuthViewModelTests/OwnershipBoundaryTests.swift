import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class OwnershipBoundaryTests: XCTestCase {
    func testUnapprovedSignupCannotCreateAccountOrWriteProfilesEvenWithRepositories() async {
        let f = AuthFixture()
        let setup = SignupResetTests()
        let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: setup.configuration)
        setup.ready(vm)
        await vm.submit()
        await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0)
        XCTAssertEqual(f.auth.signInCount, 0)
        XCTAssertEqual(f.users.saves, 0)
        XCTAssertEqual(f.patients.saves, 0)
        XCTAssertEqual(vm.state.step, .review)
        XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertFalse(vm.state.isAccountLocked)
        XCTAssertNil(f.session.patient)
    }

    func testRecoveryURLAndOrdinarySessionCannotAuthorizePasswordWrite() async {
        let f = AuthFixture()
        f.auth.signedIn = true
        let configuration = SignupResetTests().configuration
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        let accepted = await vm.acceptRecoveryURL(configuration.redirectURL!)
        XCTAssertFalse(accepted)
        vm.state.isRecoveryReady = true
        vm.state.newPassword = "Password123!"
        vm.state.passwordConfirmation = vm.state.newPassword
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 0)
        XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertNotNil(vm.state.errorMessage)
    }
}
