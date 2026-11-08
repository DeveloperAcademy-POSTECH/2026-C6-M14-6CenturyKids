import Foundation
import XCTest
@testable import ToDocAuth

@MainActor final class PasswordRecoveryUpdateTests: XCTestCase {
    private func ready(_ f: AuthFixture) async -> PasswordResetViewModel {
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        let accepted = await vm.acceptRecoveryURL(URL(string: "todoc://auth/change-password?code=verified")!)
        XCTAssertTrue(accepted)
        vm.state.newPassword = "NewPassword123!"
        vm.state.passwordConfirmation = vm.state.newPassword
        return vm
    }

    func testSubmitChangesPasswordWithoutNonceAndCompletesAfterSignOut() async {
        let f = AuthFixture()
        let vm = await ready(f)
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertEqual(f.auth.lastUpdatedPassword, "NewPassword123!")
        XCTAssertEqual(f.auth.updateNonces.count, 1)
        XCTAssertNil(f.auth.updateNonces[0])
        XCTAssertEqual(f.auth.signOutCount, 1)
        XCTAssertTrue(vm.state.didUpdatePassword)
        XCTAssertFalse(vm.state.needsSessionCleanup)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertTrue(vm.state.newPassword.isEmpty)
        XCTAssertTrue(vm.state.passwordConfirmation.isEmpty)
        XCTAssertFalse(vm.state.isSubmitting)
        XCTAssertFalse(f.session.isBusy)
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
    }

    func testInvalidAndMismatchedPasswordsAreNotSent() async {
        let f = AuthFixture()
        let vm = await ready(f)
        vm.state.newPassword = "short"
        vm.state.passwordConfirmation = "short"
        await vm.submit()
        XCTAssertNotNil(vm.state.passwordError)
        vm.state.newPassword = "NewPassword123!"
        vm.state.passwordConfirmation = "OtherPassword123!"
        await vm.submit()
        XCTAssertNotNil(vm.state.passwordError)
        XCTAssertEqual(f.auth.updateCount, 0)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertFalse(vm.state.didUpdatePassword)
    }

    func testScreenFlagAndOrdinarySessionCannotAuthorizeUpdate() async {
        let f = AuthFixture()
        f.auth.signedIn = true
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        vm.state.isRecoveryReady = true
        vm.state.newPassword = "NewPassword123!"
        vm.state.passwordConfirmation = vm.state.newPassword
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 0)
        XCTAssertNotNil(vm.state.errorMessage)
    }

    func testFailedUpdateCanBeRetriedWithoutLosingRecoverySession() async {
        let f = AuthFixture()
        let vm = await ready(f)
        f.auth.failUpdate = true
        await vm.submit()
        XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertFalse(vm.state.needsSessionCleanup)
        XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertEqual(f.auth.signOutCount, 0)
        XCTAssertFalse(f.session.isBusy)
        f.auth.failUpdate = false
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 2)
        XCTAssertTrue(vm.state.didUpdatePassword)
        XCTAssertNil(vm.state.errorMessage)
    }

    func testCleanupRetryDoesNotUpdatePasswordAgain() async {
        let f = AuthFixture()
        let vm = await ready(f)
        f.auth.failSignOut = true
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertTrue(vm.state.needsSessionCleanup)
        XCTAssertTrue(vm.state.newPassword.isEmpty)
        XCTAssertNotNil(vm.state.errorMessage)
        f.auth.failSignOut = false
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertEqual(f.auth.signOutCount, 2)
        XCTAssertTrue(vm.state.didUpdatePassword)
        XCTAssertFalse(vm.state.needsSessionCleanup)
    }

    func testDoubleTapWhileSavingSendsOnlyOneUpdate() async {
        let f = AuthFixture()
        let vm = await ready(f)
        var resume: CheckedContinuation<Void, Never>?
        f.auth.beforeUpdate = { await withCheckedContinuation { resume = $0 } }
        let task = Task { await vm.submit() }
        while resume == nil { await Task.yield() }
        await vm.submit()
        XCTAssertEqual(f.auth.updateCount, 1)
        resume?.resume()
        await task.value
        XCTAssertTrue(vm.state.didUpdatePassword)
    }

    func testCancelDuringUpdateDiscardsSessionAndLateCompletion() async {
        let f = AuthFixture()
        let vm = await ready(f)
        var resume: CheckedContinuation<Void, Never>?
        f.auth.beforeUpdate = { await withCheckedContinuation { resume = $0 } }
        let task = Task { await vm.submit() }
        while resume == nil { await Task.yield() }
        vm.cancel()
        resume?.resume()
        await task.value
        XCTAssertFalse(vm.state.didUpdatePassword)
        XCTAssertFalse(vm.state.isRecoveryReady)
        XCTAssertFalse(f.auth.signedIn)
        XCTAssertFalse(f.session.isBusy)
        XCTAssertTrue(vm.state.newPassword.isEmpty)
    }
}
