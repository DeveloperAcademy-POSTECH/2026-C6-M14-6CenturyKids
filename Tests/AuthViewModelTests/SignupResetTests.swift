import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SignupResetTests: XCTestCase {
    let configuration = AuthConfiguration(redirectURL: URL(string: "todoc-test://auth/callback"))
    func ready(_ vm: SignupViewModel) {
        let s = vm.state
        s.step = .review; s.name = "테스트"; s.email = "patient@example.com"
        s.password = "password123"; s.passwordConfirmation = s.password
        s.birthday = Date(timeIntervalSince1970: 946684800); s.sex = .female
        s.cancerType = .lung; s.stage = .known(.stage1)
        s.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
    }
    func testSignupRequiresConfiguredTermsBeforeCreatingAccount() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: .init())
        ready(vm); await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertNotEqual(vm.state.step, .completion)
    }
    func testSignupWithoutRepositoriesCannotCreateAccount() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: .init(auth: f.auth), session: f.session, configuration: configuration)
        ready(vm); await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testUnknownStageCannotBypassAccountAuthentication() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        ready(vm); vm.state.stage = .unknown; await vm.submit()
        XCTAssertEqual(f.auth.signUpCount, 0); XCTAssertNotNil(vm.state.errorMessage)
    }
    func testDoctorRoleCannotProceedIntoPatientSignup() {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.isPatient = false; vm.handle(.next)
        XCTAssertEqual(vm.state.step, .role); XCTAssertNotNil(vm.state.currentValidationError)
    }
    func testMissingDoctorRepositoryCanBeSkipped() async {
        let f = AuthFixture(); let vm = SignupViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.step = .doctorCode; vm.state.doctorCode = "Ab12Cd34"
        await vm.verifyDoctorCode()
        XCTAssertNil(vm.state.currentValidationError)
        XCTAssertEqual(vm.state.errorMessage, "의사 연결을 준비 중이에요. 건너뛰고 다음 화면을 확인할 수 있어요.")
        vm.handle(.skipDoctorCode)
        XCTAssertEqual(vm.state.step, .review); XCTAssertNil(vm.state.connection)
    }
    func testOrdinaryLoggedInSessionCannotUpdatePasswordWithoutRecovery() async {
        let f = AuthFixture(); f.auth.signedIn = true
        let vm = PasswordResetViewModel(repositories: f.repositories, session: f.session, configuration: configuration)
        vm.state.newPassword = "newPass123"; vm.state.passwordConfirmation = "newPass123"
        await vm.submit(); XCTAssertEqual(f.auth.updateCount, 0)
    }
}
