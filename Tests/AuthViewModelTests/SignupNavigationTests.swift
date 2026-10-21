import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SignupNavigationTests: XCTestCase {
    private let configuration = AuthConfiguration(
        terms: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }),
        termsVersion: "test-v1", redirectURL: URL(string: "todoc-test://auth/callback")
    )

    private func makeViewModel(_ providedFixture: AuthFixture? = nil) -> SignupViewModel {
        let fixture = providedFixture ?? AuthFixture()
        let vm = SignupViewModel(repositories: fixture.repositories, session: fixture.session, configuration: { var c = configuration; c.allowsSignupRequests = true; return c }())
        let state = vm.state
        state.name = "테스트"; state.email = "patient@example.com"
        state.password = "password123"; state.passwordConfirmation = state.password
        state.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        return vm
    }

    private func fillRequiredProfile(_ state: SignupScreenState) {
        state.birthday = Date(timeIntervalSince1970: 946684800); state.sex = .female
        state.cancerType = .lung; state.stage = .known(.stage1)
    }

    func testRequiredProfileAndDiagnosisPrecedeOptionalDoctorCode() async {
        let vm = makeViewModel(); let state = vm.state
        state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(state.step, .patientInfo)
        vm.handle(.next)
        XCTAssertEqual(state.step, .patientInfo, "필수 생년월일·성별을 입력하기 전에 의사 코드로 갈 수 없어야 합니다.")
        XCTAssertNotNil(state.currentValidationError)

        state.birthday = Date(timeIntervalSince1970: 946684800); state.sex = .female
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerType)
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerType)
        XCTAssertNotNil(state.currentValidationError)

        state.cancerType = .lung
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerStage)
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerStage)
        XCTAssertNotNil(state.currentValidationError)

        state.stage = .known(.stage1)
        vm.handle(.next)
        XCTAssertEqual(state.step, .doctorCode)
    }

    func testSkipDoctorCodeReachesReviewAndPreservesInputsWhileSavingIsUnavailable() async {
        let fixture = AuthFixture(); let vm = makeViewModel(fixture); let state = vm.state
        fillRequiredProfile(state)
        state.step = .doctorCode; state.doctorCode = "ABC123"
        vm.handle(.skipDoctorCode)
        XCTAssertEqual(state.step, .review)
        XCTAssertTrue(state.doctorCode.isEmpty)
        XCTAssertNil(state.connection)
        await vm.submit()
        XCTAssertEqual(state.step, .review)
        XCTAssertEqual(state.name, "테스트")
        XCTAssertEqual(state.sex, .female)
        XCTAssertEqual(state.cancerType, .lung)
        XCTAssertEqual(fixture.auth.signUpCount, 0)
        XCTAssertEqual(fixture.patients.saves, 0)
        XCTAssertNotNil(state.errorMessage)
    }

    func testConfirmedDoctorAdvancesToReviewAndBackRetracesDoctorThenDiagnosis() {
        let vm = makeViewModel(); let state = vm.state
        fillRequiredProfile(state)
        state.connection = SignupDoctorConnection(hospitalName: "예시 병원", department: nil, doctorName: "예시 의사")
        state.step = .doctorConfirmation
        vm.handle(.next)
        XCTAssertEqual(state.step, .review)
        vm.handle(.back)
        XCTAssertEqual(state.step, .doctorConfirmation)
        vm.handle(.back)
        XCTAssertEqual(state.step, .doctorCode)
        vm.handle(.back)
        XCTAssertEqual(state.step, .cancerStage)
        XCTAssertEqual(state.connection?.doctorName, "예시 의사")
    }

    func testSkippedDoctorBackNavigationPreservesEarlierInputs() {
        let vm = makeViewModel(); let state = vm.state
        fillRequiredProfile(state)
        state.step = .doctorCode
        vm.handle(.skipDoctorCode)
        vm.handle(.back)
        XCTAssertEqual(state.step, .doctorCode)
        vm.handle(.back)
        XCTAssertEqual(state.step, .cancerStage)
        vm.handle(.back)
        XCTAssertEqual(state.step, .cancerType)
        vm.handle(.back)
        XCTAssertEqual(state.step, .patientInfo)
        vm.handle(.back)
        XCTAssertEqual(state.step, .terms)
        XCTAssertEqual(state.name, "테스트")
        XCTAssertEqual(state.sex, .female)
        XCTAssertEqual(state.cancerType, .lung)
    }

    func testBasicInfoEditAndBackReturnToReview() {
        let vm = makeViewModel(); let state = vm.state
        fillRequiredProfile(state); state.step = .review
        vm.handle(.editBasicInfo)
        state.name = "수정 이름"
        vm.handle(.next)
        XCTAssertEqual(state.step, .review)
        XCTAssertEqual(state.name, "수정 이름")
        vm.handle(.editBasicInfo)
        vm.handle(.back)
        XCTAssertEqual(state.step, .review)
    }

    func testDiagnosisEditReturnsToReviewWithoutRepeatingDoctorCode() {
        let vm = makeViewModel(); let state = vm.state
        fillRequiredProfile(state); state.step = .review
        state.connection = SignupDoctorConnection(hospitalName: "예시 병원", department: nil, doctorName: "예시 의사")
        vm.handle(.editDiagnosis)
        XCTAssertEqual(state.step, .cancerType)
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerStage)
        vm.handle(.back)
        XCTAssertEqual(state.step, .cancerType)
        vm.handle(.next)
        vm.handle(.next)
        XCTAssertEqual(state.step, .review)
        XCTAssertEqual(state.connection?.doctorName, "예시 의사")
        vm.handle(.editDiagnosis)
        vm.handle(.back)
        XCTAssertEqual(state.step, .review)
    }
}
