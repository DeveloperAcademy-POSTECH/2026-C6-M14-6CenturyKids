import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SignupNavigationTests: XCTestCase {
    private let configuration = AuthConfiguration(
        redirectURL: URL(string: "todoc-test://auth/callback")
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

    func testPasswordConfirmationErrorClearsAsSoonAsPasswordsMatch() {
        let vm = makeViewModel(), state = vm.state
        state.step = .passwordConfirmation
        state.passwordConfirmation = "different123"
        vm.handle(.next)
        XCTAssertEqual(state.step, .passwordConfirmation)
        XCTAssertNotNil(state.currentValidationError)

        state.passwordConfirmation = state.password
        XCTAssertTrue(state.passwordMatches)
        XCTAssertNil(state.currentValidationError, "다음을 다시 누르기 전에 이전 불일치 오류가 사라져야 합니다.")
        XCTAssertEqual(state.step, .passwordConfirmation)

        state.passwordConfirmation = "different123"
        vm.handle(.next)
        XCTAssertEqual(state.step, .passwordConfirmation)
        XCTAssertNotNil(state.currentValidationError)
        state.password = state.passwordConfirmation
        XCTAssertNil(state.currentValidationError)
        vm.handle(.next)
        XCTAssertEqual(state.step, .terms)
    }

    func testMatchingPasswordsDoesNotClearAnotherStepsValidationError() {
        let vm = makeViewModel(), state = vm.state
        state.step = .email; state.email = "invalid"
        vm.handle(.next)
        let emailError = state.currentValidationError
        XCTAssertNotNil(emailError)
        state.passwordConfirmation = "different123"
        state.password = state.passwordConfirmation
        XCTAssertTrue(state.passwordMatches)
        XCTAssertEqual(state.currentValidationError, emailError)
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

    func testUnknownStageAdvancesAndSurvivesDiagnosisEditing() {
        let vm = makeViewModel(), state = vm.state
        fillRequiredProfile(state)
        state.stage = .unknown; state.step = .cancerStage
        XCTAssertEqual(state.stageTitle, "잘 모르겠어요")
        vm.handle(.next)
        XCTAssertEqual(state.step, .doctorCode)
        vm.handle(.skipDoctorCode)
        vm.handle(.editDiagnosis)
        vm.handle(.next)
        XCTAssertEqual(state.stage, .unknown)
        vm.handle(.next)
        XCTAssertEqual(state.step, .review)
    }

    func testCustomCancerRequiresANameAndPreservesItWhileNavigating() {
        let vm = makeViewModel(), state = vm.state
        fillRequiredProfile(state); state.step = .cancerType; state.usesCustomCancer = true
        for invalid in ["", "  ", "암\n이름"] {
            state.customCancerName = invalid; vm.handle(.next)
            XCTAssertEqual(state.step, .cancerType)
            XCTAssertNotNil(state.currentValidationError)
        }
        state.customCancerName = "  난소암  "; vm.handle(.next)
        XCTAssertEqual(state.step, .cancerStage)
        XCTAssertEqual(state.cancerTitle, "난소암")
        vm.handle(.back)
        state.usesCustomCancer = false; state.cancerType = .lung
        XCTAssertEqual(state.cancerTitle, "폐암")
        state.cancerType = .unknown
        XCTAssertEqual(state.cancerTitle, "잘 모르겠어요")
        state.usesCustomCancer = true
        XCTAssertEqual(state.cancerTitle, "난소암")
        XCTAssertEqual(state.stage, .known(.stage1))
    }

    func testUnknownCancerIsSeparateFromSearchAndPreservesTheSelectedStage() {
        let vm = makeViewModel(), state = vm.state
        fillRequiredProfile(state)
        state.cancerType = .unknown
        state.stage = .known(.stage3)
        state.cancerSearch = "검색 결과 없는 이름"
        XCTAssertTrue(state.filteredCancerTypes.isEmpty)
        XCTAssertEqual(state.cancerTitle, "잘 모르겠어요")
        state.cancerSearch = ""
        XCTAssertEqual(state.filteredCancerTypes.count, 15)
        XCTAssertFalse(state.filteredCancerTypes.contains(.unknown))
        state.step = .cancerType
        vm.handle(.next)
        XCTAssertEqual(state.step, .cancerStage)
        vm.handle(.next)
        XCTAssertEqual(state.step, .doctorCode)
        vm.handle(.back); vm.handle(.back)
        XCTAssertEqual(state.step, .cancerType)
        XCTAssertEqual(state.cancerType, .unknown)
        XCTAssertEqual(state.stage, .known(.stage3))
    }
}
