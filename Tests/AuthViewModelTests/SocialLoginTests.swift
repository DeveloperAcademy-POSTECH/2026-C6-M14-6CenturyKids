import XCTest
import ToDocDomain
@testable import ToDocAuth

@MainActor final class SocialLoginTests: XCTestCase {
    func testKakaoExistingPatientEntersHome() async throws {
        let f = AuthFixture()
        try f.addProfile()
        f.auth.currentEmail = nil
        let flow = AuthFlowViewModel(repositories: f.repositories, session: AuthSessionState())
        await flow.login.signInWithKakao(idToken: "token")
        XCTAssertEqual(flow.rootRoute, .patient)
        XCTAssertTrue(flow.login.state.didSignIn)
        XCTAssertTrue(flow.session.loginPreference.isEnabled)
        XCTAssertFalse(flow.session.isBusy)
    }

    func testSocialSignupWithoutEmailCanFinishWithoutCreatingAnotherAccount() async throws {
        for apple in [false, true] {
            for email: String? in [nil, "", "  \n "] {
                let f = AuthFixture()
                f.auth.currentEmail = email
                var repositories = f.repositories
                repositories.doctors = SocialLoginDoctors()
                let flow = AuthFlowViewModel(repositories: repositories, session: AuthSessionState())
                if apple {
                    _ = try flow.login.prepareAppleSignIn()
                    await flow.login.signInWithApple(idToken: "token")
                } else {
                    await flow.login.signInWithKakao(idToken: "token")
                }
                XCTAssertEqual(flow.screen, .signup)
                XCTAssertEqual(flow.signup.state.step, .terms)
                XCTAssertTrue(flow.signup.state.email.isEmpty)
                XCTAssertFalse(flow.session.loginPreference.isEnabled)
                XCTAssertFalse(flow.login.state.didSignIn)
                flow.signup.state.acceptedTerms = Set(SignupTerm.allCases)
                await flow.signup.continueFromTerms()
                XCTAssertEqual(flow.signup.state.step, .patientInfo)
                let state = flow.signup.state
                state.name = "테스트"
                state.birthday = Date(timeIntervalSince1970: 946684800)
                state.sex = .female
                state.cancerType = .lung
                state.stage = .known(.stage1)
                state.step = .review
                await flow.signup.submit()
                XCTAssertEqual(state.step, .completion)
                XCTAssertEqual(f.auth.signUpCount, 0)
                XCTAssertEqual(f.users.value?.id, f.auth.id)
                flow.loginAfterSignup()
                XCTAssertEqual(flow.rootRoute, .patient)
            }
        }
    }

    func testKakaoFailureWrongProfileAndCancellationDoNotNavigate() async throws {
        for scenario in 0..<4 {
            let f = AuthFixture()
            let flow = AuthFlowViewModel(repositories: f.repositories, session: AuthSessionState())
            if scenario == 0 { f.auth.signInError = URLError(.timedOut) }
            if scenario == 1 { f.patients.findError = URLError(.timedOut) }
            if scenario == 2 { try f.addProfile(id: UUID()) }
            if scenario == 3 { f.patients.beforeFind = { flow.login.cancel() } }
            await flow.login.signInWithKakao(idToken: "token")
            XCTAssertEqual(flow.screen, .login)
            XCTAssertEqual(flow.rootRoute, .authentication)
            XCTAssertFalse(flow.login.state.didSignIn)
            XCTAssertFalse(flow.session.loginPreference.isEnabled)
            XCTAssertFalse(f.auth.signedIn)
            XCTAssertFalse(flow.session.isBusy)
            if scenario != 3 { XCTAssertNotNil(flow.login.state.errorMessage) }
        }
    }
}

private final class SocialLoginDoctors: DoctorRepository {
    func findById(_ id: UUID) async throws -> Doctor? { nil }
    func save(doctor: Doctor) async throws { XCTFail("가입 재개 중 의사를 저장하지 않습니다.") }
    func findByName(_ name: String) async throws -> [Doctor] { [] }
    func findByHospitalId(_ hospitalId: UUID) async throws -> [Doctor] { [] }
    func findByCode(_ code: String) async throws -> Doctor? { nil }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? { nil }
}
