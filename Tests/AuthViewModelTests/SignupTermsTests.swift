import XCTest
@testable import ToDocAuth

@MainActor final class SignupTermsTests: XCTestCase {
    private func ready(_ fixture: AuthFixture, configuration: AuthConfiguration? = nil) -> SignupViewModel {
        let configuration = configuration ?? SignupResetTests().configuration
        let vm = SignupViewModel(repositories: fixture.repositories, session: fixture.session, configuration: configuration)
        SignupResetTests().ready(vm)
        return vm
    }

    func testSixRequiredAgreementsUseProvidedCheckboxWording() {
        XCTAssertEqual(SignupTerm.allCases, [.service, .privacy, .sensitiveInformation, .doctorConnection, .thirdPartyProvision, .appUsage])
        XCTAssertTrue(SignupTerm.allCases.allSatisfy(\.isRequired))
        XCTAssertEqual(SignupTerm.allCases.map(\.fullTitle), [
            "[필수] 서비스 이용약관에 동의합니다.",
            "[필수] 개인정보 수집·이용에 동의합니다.",
            "[필수] 환자 건강정보 수집·이용에 동의합니다.",
            "[필수] 의료진·병원 정보 연동에 동의합니다.",
            "[필수] 제3자 제공에 동의합니다.",
            "[필수] 앱 이용정보 수집·이용에 동의합니다."
        ])
    }

    func testOriginalThreeAgreementsNoLongerAllowNextStep() {
        let vm = ready(AuthFixture())
        vm.state.step = .terms
        vm.state.acceptedTerms = [.service, .privacy, .sensitiveInformation]
        vm.handle(.next)
        XCTAssertEqual(vm.state.step, .terms)
        XCTAssertEqual(vm.state.currentValidationError, "필수 약관에 동의해 주세요.")
    }

    func testEachMissingAgreementBlocksAccountCreation() async {
        for missing in SignupTerm.allCases {
            let fixture = AuthFixture(), vm = ready(fixture)
            vm.state.acceptedTerms.remove(missing)
            vm.state.step = .terms
            await vm.continueFromTerms()
            XCTAssertEqual(fixture.auth.signUpCount, 0, "\(missing)")
            XCTAssertEqual(fixture.users.saves, 0)
            XCTAssertEqual(fixture.patients.saves, 0)
            XCTAssertEqual(vm.state.errorMessage, "필수 약관에 동의해 주세요.")
        }
    }

    func testAllAgreementsProceedAndSurviveBackNavigation() async {
        let vm = ready(AuthFixture())
        vm.state.step = .terms
        XCTAssertTrue(vm.state.allTermsAccepted)
        await vm.continueFromTerms()
        XCTAssertEqual(vm.state.step, .patientInfo)
        vm.handle(.back)
        XCTAssertEqual(vm.state.step, .terms)
        XCTAssertEqual(vm.state.acceptedTerms, Set(SignupTerm.allCases))
    }

    func testDefaultConfigurationAllowsSignupAfterRequiredAgreements() async {
        let configuration = AuthConfiguration()
        XCTAssertTrue(configuration.allowsSignupRequests)
        let fixture = AuthFixture(), vm = ready(fixture, configuration: configuration)
        vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(fixture.auth.signUpCount, 1)
        XCTAssertEqual(vm.state.step, .patientInfo)
        XCTAssertEqual(fixture.users.saves, 0)
        XCTAssertEqual(fixture.patients.saves, 0)
    }

    func testExplicitlyDisabledSignupStillBlocksNewAccountCreation() async {
        var configuration = AuthConfiguration()
        configuration.allowsSignupRequests = false
        let fixture = AuthFixture()
        let vm = ready(fixture, configuration: configuration)
        vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(fixture.auth.signUpCount, 0)
        XCTAssertEqual(fixture.users.saves, 0)
        XCTAssertEqual(fixture.patients.saves, 0)
        XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertFalse(vm.state.isAccountLocked)
    }

    func testNextButtonEnablesOnlyAfterEveryAgreementAndDisablesWhenOneIsRemoved() {
        let vm = ready(AuthFixture())
        vm.state.acceptedTerms = []
        for term in SignupTerm.allCases {
            XCTAssertFalse(vm.state.canProceedFromTerms)
            vm.state.acceptedTerms.insert(term)
        }
        XCTAssertTrue(vm.state.canProceedFromTerms)
        vm.state.acceptedTerms.remove(.thirdPartyProvision)
        XCTAssertFalse(vm.state.canProceedFromTerms)
    }

}
