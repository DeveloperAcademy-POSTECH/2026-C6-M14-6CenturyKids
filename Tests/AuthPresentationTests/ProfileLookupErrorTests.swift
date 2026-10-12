import XCTest
import ToDocCoreErrors
@testable import AuthPresentation

@MainActor
final class ProfileLookupErrorTests: XCTestCase {
    private let errors: [ProfileLookupError] = [.userNotFound, .patientNotFound, .doctorNotFound]

    func testEachLookupErrorDisplaysAccountGuidance() {
        for error in errors {
            XCTAssertEqual(AuthPresentationError.message(for: error, fallback: "기본 안내"),
                           "계정 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    func testFailedLoginPreservesInputAndOnlySuccessfulRetryReportsCompletion() async {
        for error in errors {
            var attempts = 0
            var completions = 0
            let login = LoginViewModel { _, _ in
                attempts += 1
                if attempts == 1 { throw error }
            }
            let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
            login.email = "patient@example.com"
            login.password = " password123 "

            await login.submit()
            flow.reportSignIn()
            XCTAssertEqual(flow.screen, .login)
            XCTAssertFalse(login.didSignIn)
            XCTAssertFalse(login.isSubmitting)
            XCTAssertEqual(completions, 0)
            XCTAssertEqual(login.email, "patient@example.com")
            XCTAssertEqual(login.password, " password123 ")
            XCTAssertEqual(login.errorMessage,
                           "계정 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")

            await login.submit()
            flow.reportSignIn()
            flow.reportSignIn()
            XCTAssertTrue(login.didSignIn)
            XCTAssertFalse(login.isSubmitting)
            XCTAssertNil(login.errorMessage)
            XCTAssertEqual(login.password, "")
            XCTAssertEqual(completions, 1)
        }
    }

    func testCancelledLookupFailureDoesNotDisplayErrorOrCompleteLogin() async throws {
        let started = expectation(description: "login requested")
        var response: CheckedContinuation<Void, Error>?
        var completions = 0
        let login = LoginViewModel { _, _ in
            try await withCheckedThrowingContinuation {
                response = $0
                started.fulfill()
            }
        }
        let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
        login.email = "patient@example.com"
        login.password = "password123"
        let request = Task { await login.submit() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        flow.cancel()
        pending.resume(throwing: ProfileLookupError.patientNotFound)
        await request.value
        flow.reportSignIn()
        XCTAssertFalse(login.isSubmitting)
        XCTAssertFalse(login.didSignIn)
        XCTAssertNil(login.errorMessage)
        XCTAssertEqual(completions, 0)
    }

    func testOldLookupFailureDoesNotOverwriteSuccessfulNewLogin() async throws {
        let started = expectation(description: "first login requested")
        var firstResponse: CheckedContinuation<Void, Error>?
        var attempts = 0
        var completions = 0
        let login = LoginViewModel { _, _ in
            attempts += 1
            if attempts == 1 {
                try await withCheckedThrowingContinuation {
                    firstResponse = $0
                    started.fulfill()
                }
            }
        }
        let flow = AuthFlowModel(login: login, onSignedIn: { completions += 1 })
        login.email = "patient@example.com"
        login.password = "password123"
        let oldRequest = Task { await login.submit() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(firstResponse)
        login.cancel()
        await login.submit()
        flow.reportSignIn()
        pending.resume(throwing: ProfileLookupError.userNotFound)
        await oldRequest.value
        flow.reportSignIn()
        XCTAssertTrue(login.didSignIn)
        XCTAssertFalse(login.isSubmitting)
        XCTAssertNil(login.errorMessage)
        XCTAssertEqual(completions, 1)
    }

    func testTaskCancellationSuppressesLateLookupError() async throws {
        let started = expectation(description: "login requested")
        var response: CheckedContinuation<Void, Error>?
        let login = LoginViewModel { _, _ in
            try await withCheckedThrowingContinuation {
                response = $0
                started.fulfill()
            }
        }
        login.email = "patient@example.com"
        login.password = "password123"
        let request = Task { await login.submit() }
        await fulfillment(of: [started], timeout: 2)
        let pending = try XCTUnwrap(response)
        request.cancel()
        pending.resume(throwing: ProfileLookupError.doctorNotFound)
        await request.value
        XCTAssertFalse(login.isSubmitting)
        XCTAssertFalse(login.didSignIn)
        XCTAssertNil(login.errorMessage)
    }

    func testCancellationErrorRemainsSilent() async {
        let login = LoginViewModel { _, _ in throw CancellationError() }
        login.email = "patient@example.com"
        login.password = "password123"
        await login.submit()
        XCTAssertFalse(login.isSubmitting)
        XCTAssertFalse(login.didSignIn)
        XCTAssertNil(login.errorMessage)
    }

    func testExistingPresentationAndUnknownErrorPoliciesArePreserved() {
        XCTAssertEqual(AuthPresentationError.message(for: AuthPresentationError.unavailable, fallback: "기본 안내"),
                       "아직 서비스를 연결하고 있어요. 잠시 후 다시 시도해 주세요.")
        XCTAssertEqual(AuthPresentationError.message(for: AuthPresentationError.message("확인된 안내"), fallback: "기본 안내"),
                       "확인된 안내")
        let serverError = NSError(domain: "server", code: 500,
                                  userInfo: [NSLocalizedDescriptionKey: "내부 서버 정보"])
        XCTAssertEqual(AuthPresentationError.message(for: serverError, fallback: "기본 안내"), "기본 안내")
    }

    func testSignupLookupFailurePreservesDraftAndCanRetry() async {
        var attempts = 0
        let terms = Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") })
        let signup = SignupViewModel(termsContent: terms, signUp: { _ in
            attempts += 1
            if attempts == 1 { throw ProfileLookupError.userNotFound }
        }, now: { Date(timeIntervalSince1970: 1_760_000_000) })
        signup.name = "김하늘"
        signup.email = "patient@example.com"
        signup.password = "password123"
        signup.passwordConfirmation = "password123"
        signup.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        signup.birthday = Date(timeIntervalSince1970: 946_684_800)
        signup.sex = .female
        signup.cancerType = .breast
        signup.stage = .known(.stage2)
        signup.skipDoctorCode()
        signup.editDiagnosis()
        signup.next()
        signup.next()
        XCTAssertEqual(signup.step, .review)

        await signup.submit()
        XCTAssertEqual(signup.step, .review)
        XCTAssertFalse(signup.isWorking)
        XCTAssertEqual(signup.errorMessage,
                       "계정 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        XCTAssertEqual(signup.password, "password123")
        XCTAssertEqual(signup.passwordConfirmation, "password123")
        XCTAssertEqual(signup.name, "김하늘")
        await signup.submit()
        XCTAssertEqual(signup.step, .completion)
        XCTAssertNil(signup.errorMessage)
        XCTAssertFalse(signup.isWorking)
        XCTAssertEqual(signup.password, "")
    }
}
