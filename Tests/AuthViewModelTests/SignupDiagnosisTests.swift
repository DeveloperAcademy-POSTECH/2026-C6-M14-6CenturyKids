import XCTest
import ToDocDomain
@testable import ToDocFeatures

@MainActor final class SignupDiagnosisTests: XCTestCase {
    private func makeViewModel(_ fixture: AuthFixture) -> SignupViewModel {
        let configuration = AuthConfiguration(
            terms: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }),
            termsVersion: "test-v1", redirectURL: URL(string: "todoc-test://auth/callback")
        )
        let vm = SignupViewModel(repositories: fixture.repositories, session: fixture.session, configuration: configuration)
        let state = vm.state
        state.name = "테스트"; state.email = "patient@example.com"
        state.password = "password123"; state.passwordConfirmation = state.password
        state.birthday = Date(timeIntervalSince1970: 946684800); state.sex = .female
        state.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        state.cancerType = .lung; state.stage = .known(.stage1)
        state.step = .review
        return vm
    }

    func testOtherCancerTextCanAdvanceAndCompleteSignup() async {
        let fixture = AuthFixture(); let vm = makeViewModel(fixture)
        vm.state.cancerType = .other
        vm.state.otherCancer = "  연부조직 육종  "
        vm.state.step = .cancerType
        vm.handle(.next)
        XCTAssertEqual(vm.state.step, .cancerStage)
        XCTAssertNil(vm.state.currentValidationError)
        vm.handle(.next)
        vm.handle(.skipDoctorCode)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(fixture.patients.value?.disease?.carcinoma.rawValue, "other")
        XCTAssertEqual(fixture.patients.value?.disease?.otherName, "연부조직 육종")
        XCTAssertEqual(vm.state.cancerTitle, "연부조직 육종")
    }

    func testUnknownStageCanAdvanceAndCompleteWithoutInventingStage() async {
        let fixture = AuthFixture(); let vm = makeViewModel(fixture)
        vm.state.stage = .unknown
        vm.state.step = .cancerStage
        vm.handle(.next)
        XCTAssertEqual(vm.state.step, .doctorCode)
        vm.handle(.skipDoctorCode)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(fixture.patients.value?.disease?.stage.rawValue, "unknown")
    }

    func testEmptyOtherCancerCannotCreateAccount() async {
        let fixture = AuthFixture(); let vm = makeViewModel(fixture)
        vm.state.cancerType = .other; vm.state.otherCancer = " \n\t "
        vm.state.step = .cancerType
        vm.handle(.next)
        XCTAssertEqual(vm.state.step, .cancerType)
        XCTAssertNotNil(vm.state.currentValidationError)
        vm.state.step = .review
        await vm.submit()
        XCTAssertEqual(fixture.auth.signUpCount, 0)
        XCTAssertNotEqual(vm.state.step, .completion)
    }

    func testReturningToKnownCancerDoesNotSaveUnusedOtherText() async {
        let fixture = AuthFixture(); let vm = makeViewModel(fixture)
        vm.state.cancerType = .other; vm.state.otherCancer = "연부조직 육종"
        vm.state.cancerType = .breast
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(fixture.patients.value?.disease?.carcinoma, .breast)
        XCTAssertNil(fixture.patients.value?.disease?.otherName)
    }

    func testRetryKeepsOriginalFreeTextAndUnknownStage() async {
        let fixture = AuthFixture(); fixture.patients.failNextSave = true
        let vm = makeViewModel(fixture)
        vm.state.cancerType = .other; vm.state.otherCancer = "연부조직 육종"; vm.state.stage = .unknown
        await vm.submit()
        XCTAssertTrue(vm.state.isAccountLocked)
        vm.state.otherCancer = "바뀐 입력"; vm.state.stage = .known(.stage4)
        await vm.submit()
        XCTAssertEqual(vm.state.step, .completion)
        XCTAssertEqual(fixture.patients.value?.disease?.otherName, "연부조직 육종")
        XCTAssertEqual(fixture.patients.value?.disease?.stage, .unknown)
    }
}
