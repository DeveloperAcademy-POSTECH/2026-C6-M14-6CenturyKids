import XCTest
import ToDocDomain
@testable import ToDocAuth

private final class LookupDoctors: DoctorRepository {
    var value: DoctorConnectionInfo? = DoctorConnectionInfo(
        doctorId: UUID(), doctorName: "테스트 의사", doctorCode: "ABC123",
        hospitalId: UUID(), hospitalName: "테스트 병원", hospitalAddress: "테스트 주소"
    )
    var error: Error?
    var codes: [String] = []
    var beforeLookup: (() async -> Void)?

    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? {
        codes.append(code)
        let response = value, failure = error
        await beforeLookup?()
        if let failure { throw failure }
        return response
    }
    func findByCode(_ code: String) async throws -> Doctor? {
        XCTFail("가입 코드 조회는 기존 통합 조회 메서드만 사용해야 합니다."); return nil
    }
    func findById(_ id: UUID) async throws -> Doctor? {
        XCTFail("가입 코드 조회는 의사 ID로 별도 조회하지 않습니다."); return nil
    }
    func save(doctor: Doctor) async throws { XCTFail("코드 확인 중 의사를 저장하면 안 됩니다.") }
    func findByName(_ name: String) async throws -> [Doctor] {
        XCTFail("코드 확인 중 이름으로 조회하면 안 됩니다."); return []
    }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] {
        XCTFail("코드 확인 중 병원 ID로 의사를 조회하면 안 됩니다."); return []
    }
}

@MainActor final class SignupDoctorLookupTests: XCTestCase {
    private let notFoundMessage = "해당 코드의 의사와 병원을 찾지 못했어요. 코드를 확인해 주세요."
    private let lookupErrorMessage = "의사 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요."

    private func model(_ doctors: LookupDoctors, fixture: AuthFixture) -> SignupViewModel {
        var repositories = fixture.repositories
        repositories.doctors = doctors
        var configuration = SignupResetTests().configuration
        configuration.allowsSignupRequests = true
        let vm = SignupViewModel(repositories: repositories, session: fixture.session, configuration: configuration)
        SignupResetTests().ready(vm)
        vm.state.step = .doctorCode; vm.state.doctorCode = "ABC123"
        return vm
    }

    private func createAccount(_ vm: SignupViewModel) async {
        vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(vm.state.step, .patientInfo)
        vm.state.step = .doctorCode
    }

    private func assertNoWrites(_ fixture: AuthFixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(fixture.auth.signUpCount, 0, file: file, line: line)
        XCTAssertEqual(fixture.users.saves, 0, file: file, line: line)
        XCTAssertEqual(fixture.patients.saves, 0, file: file, line: line)
    }

    func testUnifiedLookupNeedsNoHospitalRepositoryAndNormalizesInput() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        XCTAssertNil(vm.repositories.hospitals)
        vm.state.doctorCode = " \n abc123 \t"
        await vm.verifyDoctorCode()
        XCTAssertEqual(doctors.codes, ["ABC123"])
        XCTAssertEqual(vm.state.step, .doctorConfirmation)
        XCTAssertEqual(vm.state.connection?.doctorName, doctors.value?.doctorName)
        XCTAssertEqual(vm.state.connection?.hospitalName, doctors.value?.hospitalName)
        XCTAssertNil(vm.state.connection?.department)
        XCTAssertNil(vm.state.errorMessage)
        XCTAssertFalse(vm.state.isWorking)
        assertNoWrites(f)
    }

    func testInvalidCodeFormatNeverQueriesOrWrites() async {
        for code in ["ABC", "ABC1234", "AB12!3", "한글1234", "AB 123"] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            vm.state.doctorCode = code
            await vm.verifyDoctorCode()
            XCTAssertTrue(doctors.codes.isEmpty)
            XCTAssertNotNil(vm.state.currentValidationError)
            XCTAssertNil(vm.state.connection)
            XCTAssertEqual(vm.state.step, .doctorCode)
            XCTAssertFalse(vm.state.isWorking)
            assertNoWrites(f)
        }
    }

    func testMissingCodeAndRepositoryFailureHaveDifferentSanitizedMessages() async {
        for failure in [false, true] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            doctors.value = nil
            if failure { doctors.error = URLError(.notConnectedToInternet) }
            await vm.verifyDoctorCode()
            XCTAssertEqual(vm.state.errorMessage, failure ? lookupErrorMessage : notFoundMessage)
            XCTAssertEqual(vm.state.step, .doctorCode)
            XCTAssertNil(vm.state.connection)
            XCTAssertEqual(doctors.codes, ["ABC123"])
            assertNoWrites(f)
        }
    }

    func testRepositoryErrorCannotExposeItsPrivateMessage() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        doctors.error = AuthFlowError("내부 서버 주소와 환자 정보")
        await vm.verifyDoctorCode()
        XCTAssertEqual(vm.state.errorMessage, lookupErrorMessage)
        XCTAssertNil(vm.state.connection)
        assertNoWrites(f)
    }

    func testResponseForAnotherCodeCannotConfirmDoctor() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        doctors.value = DoctorConnectionInfo(
            doctorId: UUID(), doctorName: "다른 의사", doctorCode: "XYZ789",
            hospitalId: UUID(), hospitalName: "다른 병원", hospitalAddress: "다른 주소"
        )
        await vm.verifyDoctorCode()
        XCTAssertEqual(vm.state.errorMessage, notFoundMessage)
        XCTAssertEqual(vm.state.step, .doctorCode)
        XCTAssertNil(vm.state.connection)
        assertNoWrites(f)
    }

    func testChangingInputDiscardsLateSuccessAndErrorWithoutOverwritingCurrentMessage() async {
        for failure in [false, true] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            if failure { doctors.error = URLError(.timedOut) }
            doctors.beforeLookup = {
                vm.state.doctorCode = "XYZ789"
                vm.state.errorMessage = "새 코드를 확인해 주세요."
            }
            await vm.verifyDoctorCode()
            XCTAssertEqual(vm.state.doctorCode, "XYZ789")
            XCTAssertEqual(vm.state.step, .doctorCode)
            XCTAssertEqual(vm.state.errorMessage, "새 코드를 확인해 주세요.")
            XCTAssertNil(vm.state.connection)
            XCTAssertFalse(vm.state.isWorking)
            assertNoWrites(f)
        }
    }

    func testCancellationDiscardsLateSuccessAndError() async {
        for failure in [false, true] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            if failure { doctors.error = URLError(.timedOut) }
            doctors.beforeLookup = { vm.cancel() }
            await vm.verifyDoctorCode()
            XCTAssertEqual(vm.state.step, .doctorCode)
            XCTAssertNil(vm.state.errorMessage)
            XCTAssertNil(vm.state.connection)
            XCTAssertFalse(vm.state.isWorking)
            assertNoWrites(f)
        }
    }

    func testFailedRecheckClearsPreviousDoctorAndCannotSaveThatIdentity() async {
        for failure in [false, true] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            await createAccount(vm)
            await vm.verifyDoctorCode()
            XCTAssertNotNil(vm.state.connection)
            vm.state.step = .doctorCode
            doctors.value = nil
            if failure { doctors.error = URLError(.timedOut) }
            await vm.verifyDoctorCode()
            XCTAssertNil(vm.state.connection)
            vm.state.step = .review
            await vm.submit()
            XCTAssertEqual(f.users.saves, 0)
            XCTAssertEqual(f.patients.saves, 0)
            XCTAssertNotNil(vm.state.errorMessage)
            vm.state.doctorCode = ""
            await vm.submit()
            XCTAssertEqual(vm.state.step, .completion)
            XCTAssertNil(f.patients.value?.doctorId, "빈 코드가 이전 의사 ID를 재사용하면 안 됩니다.")
        }
    }

    func testInvalidRecheckAlsoClearsPreviousConnection() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        await vm.verifyDoctorCode()
        vm.state.step = .doctorCode; vm.state.doctorCode = "!"
        await vm.verifyDoctorCode()
        XCTAssertEqual(doctors.codes.count, 1)
        XCTAssertNil(vm.state.connection)
        XCTAssertNotNil(vm.state.currentValidationError)
        assertNoWrites(f)
    }

    func testSkipAndChangeRemovePreviouslyVerifiedIdentity() async {
        for action in [SignupAction.skipDoctorCode, .changeDoctorCode] {
            let f = AuthFixture(), doctors = LookupDoctors()
            let vm = model(doctors, fixture: f)
            await createAccount(vm)
            await vm.verifyDoctorCode()
            vm.handle(action)
            XCTAssertNil(vm.state.connection)
            vm.state.doctorCode = ""; vm.state.step = .review
            await vm.submit()
            XCTAssertEqual(vm.state.step, .completion)
            XCTAssertNil(f.patients.value?.doctorId)
            XCTAssertEqual(f.patients.saves, 1)
        }
    }

    func testFinalSaveKeepsExistingContractAndUsesOnlyVerifiedDoctorID() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        await createAccount(vm)
        await vm.verifyDoctorCode()
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        vm.handle(.next)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(f.patients.value?.doctorId, doctors.value?.doctorId)
        XCTAssertEqual(vm.completedPatient?.doctorId, doctors.value?.doctorId)
        XCTAssertEqual(f.patients.value?.user.id, f.auth.id)
        XCTAssertEqual(f.auth.signUpCount, 1)
        // TestPatients.connectToDoctor는 호출되면 실패하므로 #205 호출 추가도 검출합니다.
    }

    func testChangedUnverifiedCodeCannotBeSavedWithPreviouslyVerifiedDoctorID() async {
        let f = AuthFixture(), doctors = LookupDoctors()
        let vm = model(doctors, fixture: f)
        await createAccount(vm)
        await vm.verifyDoctorCode()
        vm.state.doctorCode = "XYZ789"; vm.state.step = .review
        await vm.submit()
        XCTAssertEqual(f.users.saves, 0); XCTAssertEqual(f.patients.saves, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
        XCTAssertNotNil(vm.state.errorMessage)
    }
}
