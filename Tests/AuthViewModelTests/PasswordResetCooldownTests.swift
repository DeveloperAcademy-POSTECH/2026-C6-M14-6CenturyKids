import Foundation
import XCTest
@testable import ToDocAuth

@MainActor final class PasswordResetCooldownTests: XCTestCase {
    func testLeavingDuringSuccessfulRequestCannotBypassCooldown() async {
        let f = AuthFixture()
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        vm.state.email = "patient@example.com"
        var resume: CheckedContinuation<Void, Never>?
        f.auth.beforeReset = { await withCheckedContinuation { resume = $0 } }
        let task = Task { await vm.submit() }
        while resume == nil { await Task.yield() }
        vm.cancel()
        resume?.resume()
        await task.value
        vm.prepareEmailRequest()
        XCTAssertGreaterThan(vm.state.resendCooldownSeconds, 0)
        await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 1)
        vm.cancel()
    }

    func testSuccessfulRequestBlocksResendsUntilDeadline() async {
        let f = AuthFixture()
        var now = Date(timeIntervalSince1970: 1000)
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session,
                                       configuration: .init(), now: { now })
        vm.state.email = "patient@example.com"
        await vm.submit()
        XCTAssertTrue(vm.state.didSend)
        XCTAssertEqual(vm.state.resendCooldownSeconds, 60)
        await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 1)

        now = now.addingTimeInterval(10)
        vm.refreshResendCooldown()
        XCTAssertEqual(vm.state.resendCooldownSeconds, 50)
        now = now.addingTimeInterval(49.5)
        await vm.requestEmail()
        XCTAssertEqual(vm.state.resendCooldownSeconds, 1)
        XCTAssertEqual(f.auth.resetCount, 1)

        now = now.addingTimeInterval(0.5)
        await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 2)
        XCTAssertEqual(vm.state.resendCooldownSeconds, 60)
        vm.cancel()
    }

    func testFailedRequestDoesNotStartCooldown() async {
        let f = AuthFixture()
        f.auth.resetError = URLError(.notConnectedToInternet)
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        vm.state.email = "patient@example.com"
        await vm.submit()
        XCTAssertFalse(vm.state.didSend)
        XCTAssertEqual(vm.state.resendCooldownSeconds, 0)
        f.auth.resetError = nil
        await vm.submit()
        XCTAssertTrue(vm.state.didSend)
        XCTAssertEqual(f.auth.resetCount, 2)
        XCTAssertEqual(vm.state.resendCooldownSeconds, 60)
        vm.cancel()
    }

    func testReopeningFormKeepsDeadlineAndElapsedTimeIsNotCountedTwice() async {
        let f = AuthFixture()
        var now = Date(timeIntervalSince1970: 1000)
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session,
                                       configuration: .init(), now: { now })
        vm.state.email = "patient@example.com"
        await vm.submit()
        vm.cancel()
        now = now.addingTimeInterval(15)
        vm.prepareEmailRequest()
        XCTAssertEqual(vm.state.resendCooldownSeconds, 45)
        await vm.submit()
        XCTAssertEqual(f.auth.resetCount, 1)
        now = now.addingTimeInterval(100)
        vm.refreshResendCooldown()
        XCTAssertEqual(vm.state.resendCooldownSeconds, 0)
        vm.cancel()
    }

    func testFailedResendPreservesSentEmailScreenAndCanRetry() async {
        let f = AuthFixture()
        var now = Date(timeIntervalSince1970: 1000)
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session,
                                       configuration: .init(), now: { now })
        vm.state.email = "patient@example.com"
        await vm.submit()
        now = now.addingTimeInterval(60)
        f.auth.resetError = URLError(.notConnectedToInternet)
        await vm.submit()
        XCTAssertTrue(vm.state.didSend)
        XCTAssertEqual(vm.state.resendCooldownSeconds, 0)
        XCTAssertNotNil(vm.state.errorMessage)
        vm.cancel()
    }
}
