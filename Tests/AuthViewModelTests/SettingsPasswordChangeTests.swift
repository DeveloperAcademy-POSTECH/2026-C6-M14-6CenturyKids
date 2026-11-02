#if canImport(Auth)
import XCTest
import ToDocDomain
import enum Auth.AuthError
import struct Auth.ErrorCode
@testable import ToDocAuth

/// 설정의 비밀번호 변경은 서버에서 인증코드를 확인한 뒤에만 새 비밀번호를 저장합니다.
@MainActor final class SettingsPasswordChangeTests: XCTestCase {
    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "Untrusted server detail", errorCode: code, underlyingData: Data(),
             underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.invalid/auth")!,
                                                  statusCode: 403, httpVersion: nil, headerFields: nil)!)
    }
    private func model(_ f: AuthFixture) -> SettingsViewModel {
        SettingsViewModel(patientId: f.auth.id, authRepository: f.auth, authSession: f.session,
                          userRepository: f.users, patientRepository: f.patients,
                          doctorRepository: NoDoctors(), hospitalRepository: NoHospitals())
    }

    func testWrongCodeStopsBeforeNewPassword() async {
        let f = AuthFixture(); f.auth.verifyError = apiError(.otpExpired)
        let vm = model(f)
        await vm.sendPasswordChangeCode()
        vm.passwordChangeState.verificationCode = "000000"
        let moved = await vm.continuePasswordChange()
        XCTAssertFalse(moved)
        XCTAssertNotNil(vm.passwordChangeState.codeError)

        vm.passwordChangeState.newPassword = "newPass12!"; vm.passwordChangeState.passwordConfirmation = "newPass12!"
        await vm.changePassword()
        XCTAssertEqual(f.auth.updateCount, 0, "확인되지 않은 코드로는 비밀번호를 바꾸지 않습니다.")
        XCTAssertFalse(vm.passwordChangeState.didSave)
    }

    func testVerifiedCodeAllowsPasswordChange() async {
        let f = AuthFixture(); let vm = model(f)
        await vm.sendPasswordChangeCode()
        XCTAssertEqual(f.auth.resetCount, 1)
        vm.passwordChangeState.verificationCode = " 123456 "
        let moved = await vm.continuePasswordChange()
        XCTAssertTrue(moved)
        XCTAssertEqual(f.auth.lastEmail, f.auth.currentEmail); XCTAssertEqual(f.auth.lastCode, "123456")

        vm.passwordChangeState.newPassword = "newPass12!"; vm.passwordChangeState.passwordConfirmation = "newPass12!"
        await vm.changePassword()
        XCTAssertEqual(f.auth.updateCount, 1)
        XCTAssertTrue(vm.passwordChangeState.didSave)
    }
}

private final class NoDoctors: DoctorRepository {
    func save(doctor: Doctor) async throws {}
    func findById(_ id: UUID) async throws -> Doctor? { nil }
    func findByName(_ name: String) async throws -> [Doctor] { [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { [] }
    func findByCode(_ code: String) async throws -> Doctor? { nil }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? { nil }
}
private final class NoHospitals: HospitalRepository {
    func findById(_ id: UUID) async throws -> Hospital? { nil }
    func findByName(_ name: String) async throws -> [Hospital] { [] }
    func findByCode(_ code: String) async throws -> Hospital? { nil }
    func searchByAddress(_ keyword: String) async throws -> [Hospital] { [] }
}
#endif
