import XCTest
@testable import ToDocAuth

@MainActor final class SignupTermsTests: XCTestCase {
    private func ready(_ fixture: AuthFixture, configuration: AuthConfiguration? = nil) -> SignupViewModel {
        var configuration = configuration ?? SignupResetTests().configuration
        configuration.allowsSignupRequests = true
        let vm = SignupViewModel(repositories: fixture.repositories, session: fixture.session, configuration: configuration)
        SignupResetTests().ready(vm)
        return vm
    }

    func testFiveRequiredAgreementsUseProvidedCheckboxWording() {
        XCTAssertEqual(SignupTerm.allCases, [.service, .privacy, .sensitiveInformation, .doctorConnection, .thirdPartyProvision])
        XCTAssertTrue(SignupTerm.allCases.allSatisfy(\.isRequired))
        XCTAssertEqual(SignupTerm.allCases.map(\.fullTitle), [
            "[필수] 서비스 이용약관에 동의합니다.",
            "[필수] 개인정보 수집·이용에 동의합니다.",
            "[필수] 건강정보(민감정보)의 수집·이용에 동의합니다.",
            "[필수] 의료진·병원 연결 절차에 동의합니다.",
            "[필수] 연결된 의료진·병원에 대한 개인정보 제공에 동의합니다."
        ])
    }

    func testProvidedDocumentsUseConfirmedNamesVersionAndEffectiveDate() {
        let vm = SignupViewModel(repositories: .init(), session: AuthFixture().session, configuration: .init())
        XCTAssertEqual(vm.state.termsContent.count, 5)
        XCTAssertTrue(vm.state.termsContent[.service]?.contains("의료진의 진단이나 치료를 대신하지 않습니다.") == true)
        XCTAssertTrue(vm.state.termsContent[.privacy]?.contains("이메일, 이름, 생년월일") == true)
        XCTAssertTrue(vm.state.termsContent[.sensitiveInformation]?.contains("통증 부위와 점수") == true)
        XCTAssertTrue(vm.state.termsContent[.doctorConnection]?.contains("의료진이 요청을 승인한 뒤") == true)
        XCTAssertTrue(vm.state.termsContent[.thirdPartyProvision]?.contains("연결 해제·탈퇴 시 앱 내 접근 및 새 공유 중단") == true)
        XCTAssertTrue(vm.state.hasRequiredTermsContent)
        XCTAssertEqual(vm.state.termsVersion, "1.0")
        XCTAssertEqual(vm.state.termsEffectiveDate, "2026-10-21")
        XCTAssertTrue(vm.state.termsContent[.service]?.contains("세기의 아이들은") == true)
        XCTAssertTrue(vm.state.termsContent[.service]?.contains("c6 서비스 이용약관") == true)
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

    func testDefaultTermsDoNotAutomaticallyEnableSignupRequests() async {
        let configuration = AuthConfiguration()
        XCTAssertTrue(configuration.hasRequiredTerms)
        XCTAssertFalse(configuration.allowsSignupRequests)
        let fixture = AuthFixture()
        let vm = SignupViewModel(repositories: fixture.repositories, session: fixture.session, configuration: configuration)
        SignupResetTests().ready(vm)
        vm.state.step = .terms
        await vm.continueFromTerms()
        XCTAssertEqual(fixture.auth.signUpCount, 0)
        XCTAssertNotNil(vm.state.errorMessage)
        XCTAssertFalse(vm.state.isAccountLocked)
    }

    func testMissingMetadataPlaceholdersAndMissingDocumentsCannotProceed() {
        var configuration = AuthConfiguration()
        configuration.termsVersion = nil
        XCTAssertFalse(configuration.hasRequiredTerms)
        configuration.termsVersion = "1.0"
        configuration.termsEffectiveDate = nil
        XCTAssertFalse(configuration.hasRequiredTerms)
        configuration.termsEffectiveDate = "2026-10-21"
        configuration.terms[.service] = "[서비스명] 서비스 이용약관"
        XCTAssertFalse(configuration.hasRequiredTerms)
        configuration.terms = SignupTermsContent.provided
        XCTAssertTrue(configuration.hasRequiredTerms)
        configuration.terms[.thirdPartyProvision] = " \n "
        XCTAssertFalse(configuration.hasRequiredTerms)
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

#if DEBUG
    func testLocalTestCannotSubmitWithAnyMissingAgreementOrDocument() async {
        for missing in SignupTerm.allCases {
            for removesDocument in [false, true] {
                var configuration = AuthConfiguration()
                configuration.localSignupTest = true
                if removesDocument { configuration.terms[missing] = nil }
                let fixture = AuthFixture(), vm = ready(fixture, configuration: configuration)
                if !removesDocument { vm.state.acceptedTerms.remove(missing) }
                vm.state.step = .terms
                await vm.continueFromTerms()
                XCTAssertEqual(fixture.auth.signUpCount, 0)
                XCTAssertEqual(fixture.users.saves, 0)
                XCTAssertEqual(fixture.patients.saves, 0)
                XCTAssertFalse(vm.state.isAccountLocked)
            }
        }
    }
#endif
}
