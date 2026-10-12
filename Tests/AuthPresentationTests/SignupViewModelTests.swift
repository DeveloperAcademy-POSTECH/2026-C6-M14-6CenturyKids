import XCTest
@testable import AuthPresentation
import ToDocDomain

@MainActor
final class SignupViewModelTests: XCTestCase {
    private func fill(_ model: SignupViewModel) {
        model.name = " 김하늘 "
        model.email = " p@example.com "
        model.password = "abc12345 "
        model.passwordConfirmation = model.password
        model.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        model.birthday = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        model.sex = .female
        model.cancerType = .breast
        model.stage = .known(.stage2)
    }

    func testRequiredTermsAndPasswordMismatchBlockAdvancing() {
        let model = SignupViewModel()
        model.next()
        XCTAssertEqual(model.step, .name)
        model.next()
        XCTAssertEqual(model.step, .name)
        model.name = "김하늘"; model.next()
        model.email = "p@example.com"; model.next()
        model.password = "abc12345"; model.next()
        model.passwordConfirmation = "wrong"; model.next()
        XCTAssertEqual(model.step, .passwordConfirmation)
        model.passwordConfirmation = model.password; model.next()
        model.next()
        XCTAssertEqual(model.step, .terms)
        model.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired)); model.next()
        XCTAssertEqual(model.step, .doctorCode)
    }

    func testReviewEditsPreserveDraftAndReturnToReview() {
        let model = SignupViewModel()
        fill(model)
        model.editBasicInfo()
        XCTAssertEqual(model.step, .patientInfo)
        model.name = "김가을"; model.next()
        XCTAssertEqual(model.step, .review)
        XCTAssertEqual(model.email, " p@example.com ")
        model.editDiagnosis()
        XCTAssertEqual(model.step, .cancerType)
        model.next(); model.next()
        XCTAssertEqual(model.step, .review)
        XCTAssertEqual(model.name, "김가을")
    }

    func testFutureBirthdayAndUnselectedStageAreRejected() {
        let model = SignupViewModel()
        fill(model)
        model.birthday = Date().addingTimeInterval(86400)
        XCTAssertNotNil(model.patientInfoError)
        model.stage = nil
        XCTAssertNotNil(model.stageError)
        model.stage = .unknown
        XCTAssertNil(model.stageError)
    }

    func testChangedDoctorCodeIgnoresStaleLookup() async {
        var continuation: CheckedContinuation<SignupDoctorConnection, Never>?
        let model = SignupViewModel(lookupDoctor: { _ in
            await withCheckedContinuation { continuation = $0 }
        })
        model.doctorCode = "A12B34"
        let task = Task { await model.verifyDoctorCode() }
        while continuation == nil { await Task.yield() }
        model.doctorCode = "C56D78"
        continuation?.resume(returning: .init(hospitalName: "테스트 병원", department: nil, doctorName: "테스트 의사"))
        await task.value
        XCTAssertNil(model.connection)
        XCTAssertFalse(model.isWorking)
    }

    func testSuccessfulCodeIsInvalidatedOnEditAndSkip() async {
        let model = SignupViewModel(lookupDoctor: { _ in
            .init(hospitalName: "테스트 병원", department: nil, doctorName: "테스트 의사")
        })
        model.doctorCode = "A12B34"
        await model.verifyDoctorCode()
        XCTAssertNotNil(model.connection)
        model.doctorCode = "B12B34"
        XCTAssertNil(model.connection)
        model.skipDoctorCode()
        XCTAssertEqual(model.doctorCode, "")
        XCTAssertEqual(model.step, .patientInfo)
    }

    func testSubmissionPreservesCustomDiagnosisAndPasswordAndCanRetry() async {
        var payload: SignupSubmission?
        var calls = 0
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }), signUp: {
            payload = $0
            calls += 1
            if calls == 1 { throw AuthPresentationError.message("다시 시도해 주세요.") }
        })
        fill(model)
        model.usesOtherCancer = true; model.otherCancer = " 기타 암종 "
        model.stage = .other; model.otherStage = " 다른 병기 표현 "
        await model.submit()
        XCTAssertNotEqual(model.step, .completion)
        XCTAssertNotNil(model.errorMessage)
        await model.submit()
        XCTAssertEqual(model.step, .completion)
        XCTAssertEqual(payload?.email, "p@example.com")
        XCTAssertEqual(payload?.password, "abc12345 ")
        XCTAssertEqual(payload?.cancer, .other("기타 암종"))
        XCTAssertEqual(payload?.stage, .other("다른 병기 표현"))
        XCTAssertEqual(model.password, "")
        XCTAssertEqual(model.passwordConfirmation, "")
    }

    func testMissingTermsBodyCannotCreateAccount() async {
        var calls = 0
        let model = SignupViewModel(signUp: { _ in calls += 1 })
        fill(model)
        await model.submit()
        XCTAssertEqual(calls, 0)
        XCTAssertNotEqual(model.step, .completion)
        XCTAssertNotNil(model.errorMessage)
    }

    func testDuplicateAndCancelledSubmissionNeverCompletes() async {
        var calls = 0
        var continuation: CheckedContinuation<Void, Never>?
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }), signUp: { _ in
            calls += 1
            await withCheckedContinuation { continuation = $0 }
        })
        fill(model)
        let task = Task { await model.submit() }
        while continuation == nil { await Task.yield() }
        await model.submit()
        XCTAssertEqual(calls, 1)
        model.cancel()
        continuation?.resume()
        await task.value
        XCTAssertNotEqual(model.step, .completion)
        XCTAssertFalse(model.isWorking)
    }
    func testAcceptedOptionalTermAlsoNeedsItsBody() async {
        var calls = 0
        let required = SignupTerm.allCases.filter(\.isRequired)
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: required.map { ($0, "테스트 약관") }), signUp: { _ in calls += 1 })
        fill(model)
        model.setAllTerms(true)
        await model.submit()
        XCTAssertEqual(calls, 0)
        XCTAssertNotEqual(model.step, .completion)
    }

    func testAlreadyCancelledLookupAndSignupNeverCallService() async {
        var calls = 0
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }), lookupDoctor: { _ in
            calls += 1
            return .init(hospitalName: "테스트 병원", department: nil, doctorName: "테스트 의사")
        }, signUp: { _ in calls += 1 })
        model.doctorCode = "A12B34"
        let lookup = Task { await model.verifyDoctorCode() }
        lookup.cancel()
        await lookup.value
        model.skipDoctorCode()
        fill(model)
        let signup = Task { await model.submit() }
        signup.cancel()
        await signup.value
        XCTAssertEqual(calls, 0)
    }


    func testReviewCannotOpenBasicInfoWhileSignupIsPending() async {
        await assertPendingSignupPreventsReviewEdit { $0.editBasicInfo() }
    }

    func testReviewCannotOpenDiagnosisWhileSignupIsPending() async {
        await assertPendingSignupPreventsReviewEdit { $0.editDiagnosis() }
    }

    private func assertPendingSignupPreventsReviewEdit(_ edit: (SignupViewModel) -> Void) async {
        var continuation: CheckedContinuation<Void, Error>?
        let model = SignupViewModel(termsContent: Dictionary(uniqueKeysWithValues: SignupTerm.allCases.map { ($0, "테스트 약관") }), signUp: { _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        })
        fill(model)
        model.editBasicInfo(); model.next()
        XCTAssertEqual(model.step, .review)
        let request = Task { await model.submit() }
        while continuation == nil { await Task.yield() }
        edit(model)
        XCTAssertEqual(model.step, .review, "제출 중에는 검토 화면을 유지해야 합니다.")
        XCTAssertTrue(model.isWorking)
        continuation?.resume(throwing: AuthPresentationError.message("재시도"))
        await request.value
        XCTAssertFalse(model.isWorking)
        XCTAssertEqual(model.step, .review)
        XCTAssertEqual(model.name, " 김하늘 ")
        XCTAssertNotNil(model.errorMessage)
        edit(model)
        XCTAssertNotEqual(model.step, .review, "실패 후에는 초안을 수정할 수 있어야 합니다.")
    }
}
