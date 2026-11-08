import Foundation
import XCTest
import Auth
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SettingsPasswordChangeTests: XCTestCase {
    private func ready(_ f: AuthFixture) -> SettingsViewModel {
        let vm = SettingsViewModel(patientId: f.auth.id, authRepository: f.auth, authSession: f.session,
                                   userRepository: f.users, patientRepository: f.patients,
                                   doctorRepository: UnusedDoctors(), hospitalRepository: UnusedHospitals())
        vm.passwordChangeState.newPassword = "NewPassword123!"
        vm.passwordChangeState.passwordConfirmation = "NewPassword123!"
        vm.validatePasswordInputs()
        return vm
    }

    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "Test error", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.com/auth/v1/user")!,
                                                 statusCode: 400, httpVersion: nil, headerFields: nil)!)
    }

    func testRecentSessionChangesPasswordWithoutRequestingOrSendingNonce() async {
        let f = AuthFixture()
        let vm = ready(f)
        // 이전 입력이 남아 있어도 최초 요청에는 nonce를 포함하지 않습니다.
        vm.passwordChangeState.verificationCode = "stale-code"
        await vm.changePassword()
        XCTAssertTrue(vm.passwordChangeState.didSave)
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertNil(f.auth.updateNonces[0])
        XCTAssertEqual(f.auth.verificationCount, 0)
        XCTAssertFalse(vm.passwordChangeState.requiresReauthentication)
        XCTAssertTrue(vm.passwordChangeState.newPassword.isEmpty)
    }

    func testReauthenticationIsRequestedOnlyAfterServerRequiresIt() async {
        let f = AuthFixture()
        let vm = ready(f)
        await vm.sendPasswordChangeCode()
        XCTAssertEqual(f.auth.verificationCount, 0)
        f.auth.updateError = apiError(.reauthenticationNeeded)
        await vm.changePassword()
        XCTAssertFalse(vm.passwordChangeState.didSave)
        XCTAssertNil(f.auth.updateNonces[0])
        XCTAssertTrue(vm.passwordChangeState.requiresReauthentication)
        XCTAssertTrue(vm.passwordChangeState.hasSentCode)
        XCTAssertEqual(f.auth.verificationCount, 1)
        XCTAssertEqual(vm.passwordChangeState.newPassword, "NewPassword123!")
        XCTAssertFalse(vm.passwordChangeState.isSaving)
        XCTAssertFalse(vm.passwordChangeState.isSendingCode)

        f.auth.updateError = nil
        vm.passwordChangeState.verificationCode = " 123456 "
        await vm.changePassword()
        XCTAssertEqual(f.auth.updateCount, 2)
        XCTAssertEqual(f.auth.updateNonces[1], "123456")
        XCTAssertTrue(vm.passwordChangeState.didSave)
        XCTAssertFalse(vm.passwordChangeState.requiresReauthentication)
    }

    func testIncorrectCodeCannotCompleteChangeAndCanBeCorrected() async {
        let f = AuthFixture()
        let vm = ready(f)
        f.auth.updateError = apiError(.reauthenticationNeeded)
        await vm.changePassword()
        vm.passwordChangeState.verificationCode = "wrong"
        f.auth.updateError = apiError(.reauthenticationNotValid)
        await vm.changePassword()
        XCTAssertFalse(vm.passwordChangeState.didSave)
        XCTAssertNotNil(vm.passwordChangeState.codeError)
        XCTAssertTrue(vm.passwordChangeState.requiresReauthentication)
        XCTAssertEqual(f.auth.verificationCount, 1)
        vm.passwordChangeState.verificationCode = "123456"
        f.auth.updateError = nil
        await vm.changePassword()
        XCTAssertTrue(vm.passwordChangeState.didSave)
        XCTAssertNil(vm.passwordChangeState.codeError)
    }

    func testSendFailureCanRetryButCannotUpdateWithUnsentCode() async {
        let f = AuthFixture()
        let vm = ready(f)
        f.auth.updateError = apiError(.reauthenticationNeeded)
        f.auth.verificationError = URLError(.notConnectedToInternet)
        await vm.changePassword()
        XCTAssertFalse(vm.passwordChangeState.hasSentCode)
        XCTAssertNotNil(vm.passwordChangeState.errorMessage)
        vm.passwordChangeState.verificationCode = "123456"
        await vm.changePassword()
        XCTAssertEqual(f.auth.updateCount, 1)
        f.auth.verificationError = nil
        await vm.sendPasswordChangeCode()
        XCTAssertTrue(vm.passwordChangeState.hasSentCode)
        XCTAssertTrue(vm.passwordChangeState.verificationCode.isEmpty)
        XCTAssertEqual(f.auth.verificationCount, 2)
    }

    func testOtherFailuresDoNotRequestReauthentication() async {
        for error in [apiError(.samePassword), apiError(.weakPassword)] {
            let f = AuthFixture()
            let vm = ready(f)
            f.auth.updateError = error
            await vm.changePassword()
            XCTAssertFalse(vm.passwordChangeState.didSave)
            XCTAssertFalse(vm.passwordChangeState.requiresReauthentication)
            XCTAssertNotNil(vm.passwordChangeState.newPasswordError)
            XCTAssertEqual(f.auth.verificationCount, 0)
        }
    }

    func testReturningToPasswordEntryDropsCodeButKeepsPasswordDraft() async {
        let f = AuthFixture()
        let vm = ready(f)
        f.auth.updateError = apiError(.reauthenticationNeeded)
        await vm.changePassword()
        vm.passwordChangeState.verificationCode = "123456"
        vm.returnToPasswordEntry()
        XCTAssertFalse(vm.passwordChangeState.requiresReauthentication)
        XCTAssertFalse(vm.passwordChangeState.hasSentCode)
        XCTAssertTrue(vm.passwordChangeState.verificationCode.isEmpty)
        XCTAssertEqual(vm.passwordChangeState.newPassword, "NewPassword123!")
        f.auth.updateError = nil
        await vm.changePassword()
        XCTAssertNil(f.auth.updateNonces[1])
    }

    func testExitDuringChangeDoesNotTriggerCodeRequestOrCompletion() async {
        let f = AuthFixture()
        let vm = ready(f)
        var resume: CheckedContinuation<Void, Never>?
        f.auth.beforeUpdate = { await withCheckedContinuation { resume = $0 } }
        f.auth.updateError = apiError(.reauthenticationNeeded)
        let task = Task { await vm.changePassword() }
        while resume == nil { await Task.yield() }
        await vm.changePassword()
        XCTAssertEqual(f.auth.updateCount, 1)
        vm.discardPasswordChange()
        resume?.resume()
        await task.value
        XCTAssertFalse(vm.passwordChangeState.didSave)
        XCTAssertFalse(vm.passwordChangeState.requiresReauthentication)
        XCTAssertTrue(vm.passwordChangeState.newPassword.isEmpty)
        XCTAssertEqual(f.auth.verificationCount, 0)
        XCTAssertFalse(vm.passwordChangeState.isSaving)
    }
}

private struct UnusedDoctors: DoctorRepository {
    func save(doctor: Doctor) async throws {}
    func findById(_ id: UUID) async throws -> Doctor? { nil }
    func findByName(_ name: String) async throws -> [Doctor] { [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { [] }
    func findByCode(_ code: String) async throws -> Doctor? { nil }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? { nil }
}

private struct UnusedHospitals: HospitalRepository {
    func findById(_ id: UUID) async throws -> Hospital? { nil }
    func findByName(_ name: String) async throws -> [Hospital] { [] }
    func findByCode(_ code: String) async throws -> Hospital? { nil }
    func searchByAddress(_ keyword: String) async throws -> [Hospital] { [] }
}
