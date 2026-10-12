import Foundation
import Observation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

@MainActor @Observable
final class SignupViewModel {
    typealias SignUp = @MainActor @Sendable (SignupSubmission) async throws -> Void
    typealias LookupDoctor = @MainActor @Sendable (String) async throws -> SignupDoctorConnection

    private(set) var step: SignupStep = .role
    var isPatient = true
    var name = ""
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var acceptedTerms: Set<SignupTerm> = []
    var doctorCode = "" {
        didSet {
            if doctorCode != oldValue {
                connection = nil
                verifiedCode = nil
                cancel()
            }
        }
    }
    private(set) var connection: SignupDoctorConnection?
    var birthday: Date?
    var sex: Sex?
    var cancerType: CarcinomaType?
    var usesOtherCancer = false
    var otherCancer = ""
    var cancerSearch = ""
    var stage: SignupStageChoice?
    var otherStage = ""
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    private(set) var hasAttemptedStep = false
    let termsContent: [SignupTerm: String]
    @ObservationIgnored private let now: () -> Date
    let calendar: Calendar
    @ObservationIgnored private let signUp: SignUp
    @ObservationIgnored private let lookupDoctor: LookupDoctor
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var verifiedCode: String?
    @ObservationIgnored private var editingReview = false

    init(termsContent: [SignupTerm: String] = [:],
         lookupDoctor: @escaping LookupDoctor = { _ in throw AuthPresentationError.unavailable },
         signUp: @escaping SignUp = { _ in throw AuthPresentationError.unavailable },
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current) {
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.termsContent = termsContent
        self.lookupDoctor = lookupDoctor
        self.signUp = signUp
    }

    var allTermsAccepted: Bool { SignupTerm.allCases.allSatisfy { acceptedTerms.contains($0) } }
    var requiredTermsAccepted: Bool { SignupTerm.allCases.filter(\.isRequired).allSatisfy { acceptedTerms.contains($0) } }
    var hasRequiredTermsContent: Bool {
        SignupTerm.allCases.filter(\.isRequired).allSatisfy { !AuthFormValidation.trimmed(termsContent[$0] ?? "").isEmpty }
    }
    var age: Int? {
        guard let birthday else { return nil }
        let instant = now()
        guard (try? DomainDateRules.validateBirthday(birthday, now: instant, calendar: calendar)) != nil else { return nil }
        return DomainDateRules.age(birthday: birthday, now: instant, calendar: calendar)
    }
    var latestBirthday: Date {
        let instant = now()
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: instant))?
            .addingTimeInterval(-1) ?? instant
    }
    var birthdayText: String? {
        guard let birthday else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
        return formatter.string(from: birthday)
    }
    var filteredCancerTypes: [CarcinomaType] {
        let search = AuthFormValidation.trimmed(cancerSearch)
        return CarcinomaType.allCases.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var cancerTitle: String { usesOtherCancer ? AuthFormValidation.trimmed(otherCancer) : (cancerType?.title ?? "선택 전") }
    var stageTitle: String {
        switch stage {
        case .known(let stage): stage.title
        case .unknown: "잘 모르겠어요"
        case .other: AuthFormValidation.trimmed(otherStage)
        case nil: "선택 전"
        }
    }
    var patientInfoError: String? {
        if let error = AuthFormValidation.nameError(name) { return error }
        guard let birthday else { return "생년월일을 선택해 주세요." }
        guard (try? DomainDateRules.validateBirthday(birthday, now: now(), calendar: calendar)) != nil else {
            return "생년월일은 오늘 이후일 수 없어요."
        }
        guard sex != nil else { return "성별을 선택해 주세요." }
        return nil
    }
    var cancerError: String? {
        if usesOtherCancer { return AuthFormValidation.trimmed(otherCancer).isEmpty ? "암 이름을 입력해 주세요." : nil }
        return cancerType == nil ? "진단받은 암을 선택해 주세요." : nil
    }
    var stageError: String? {
        guard let stage else { return "병기를 선택해 주세요." }
        return stage == .other && AuthFormValidation.trimmed(otherStage).isEmpty ? "들으신 병기 표현을 입력해 주세요." : nil
    }
    var currentValidationError: String? {
        switch step {
        case .role: isPatient ? nil : "의사 계정은 iPad에서 이용해 주세요."
        case .name: AuthFormValidation.nameError(name)
        case .email: AuthFormValidation.emailError(email)
        case .password: AuthFormValidation.passwordError(password)
        case .passwordConfirmation: password == passwordConfirmation && !passwordConfirmation.isEmpty ? nil : "비밀번호가 일치하지 않아요."
        case .terms: requiredTermsAccepted ? nil : "필수 약관에 모두 동의해 주세요."
        case .doctorCode: validDoctorCode ? nil : "영문·숫자로 된 6자리 코드를 입력해 주세요."
        case .doctorConfirmation: connection == nil ? "연결 코드를 다시 확인해 주세요." : nil
        case .patientInfo: patientInfoError
        case .cancerType: cancerError
        case .cancerStage: stageError
        case .review, .completion: nil
        }
    }
    private var validDoctorCode: Bool {
        AuthFormValidation.trimmed(doctorCode).range(of: "^[A-Za-z0-9]{6}$", options: .regularExpression) != nil
    }

    /// 완료된 가입에서 새 계정을 입력할 때도 외부에서 전달한 기능을 유지합니다.
    func newDraft() -> SignupViewModel {
        SignupViewModel(termsContent: termsContent, lookupDoctor: lookupDoctor, signUp: signUp,
                        now: now, timeZone: calendar.timeZone)
    }

    func setAllTerms(_ accepted: Bool) {
        acceptedTerms = accepted ? Set(SignupTerm.allCases) : []
    }

    func next() {
        guard !isWorking, step != .completion else { return }
        hasAttemptedStep = true
        errorMessage = nil
        guard currentValidationError == nil else { return }
        if editingReview && (step == .patientInfo || step == .cancerStage) {
            editingReview = false
            move(to: .review)
        } else if step != .doctorCode && step != .review,
                  let next = SignupStep(rawValue: step.rawValue + 1) { move(to: next) }
    }

    func back() {
        guard step != .completion else { return }
        cancel()
        if editingReview {
            // 수정 중 입력은 유지하며 검토 화면으로 돌아갑니다.
            editingReview = false
            move(to: .review)
        } else if step == .patientInfo {
            move(to: connection == nil ? .doctorCode : .doctorConfirmation)
        } else if let previous = SignupStep(rawValue: step.rawValue - 1) { move(to: previous) }
    }

    func editBasicInfo() { editingReview = true; move(to: .patientInfo) }
    func editDiagnosis() { editingReview = true; move(to: .cancerType) }
    func changeDoctorCode() { cancel(); move(to: .doctorCode) }
    func skipDoctorCode() {
        cancel()
        doctorCode = ""
        connection = nil
        verifiedCode = nil
        move(to: .patientInfo)
    }

    func verifyDoctorCode() async {
        guard !Task.isCancelled, !isWorking else { return }
        hasAttemptedStep = true
        errorMessage = nil
        guard validDoctorCode else { return }
        let code = AuthFormValidation.trimmed(doctorCode)
        let id = beginRequest()
        defer { if requestID == id { isWorking = false } }
        do {
            let result = try await lookupDoctor(code)
            guard requestID == id, !Task.isCancelled else { return }
            connection = result
            verifiedCode = code
            move(to: .doctorConfirmation)
        } catch {
            guard requestID == id, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = AuthPresentationError.message(for: error, fallback: "연결 코드를 확인하지 못했어요. 코드를 확인하고 다시 시도해 주세요.")
        }
    }

    func submit() async {
        guard !Task.isCancelled, !isWorking, step != .completion else { return }
        errorMessage = nil
        let validation = AuthFormValidation.emailError(email) ?? AuthFormValidation.passwordError(password)
            ?? (password == passwordConfirmation ? nil : "비밀번호가 일치하지 않아요.")
            ?? patientInfoError ?? cancerError ?? stageError
            ?? (requiredTermsAccepted ? nil : "필수 약관에 모두 동의해 주세요.")
        if let validation { errorMessage = validation; return }
        guard hasRequiredTermsContent, acceptedTerms.allSatisfy({
            !AuthFormValidation.trimmed(termsContent[$0] ?? "").isEmpty
        }) else {
            errorMessage = "약관 본문을 준비하고 있어요. 약관이 제공되면 가입을 완료할 수 있어요."
            return
        }
        guard doctorCode.isEmpty || (verifiedCode == AuthFormValidation.trimmed(doctorCode) && connection != nil) else {
            errorMessage = "의사 연결 코드를 확인하거나 건너뛰기를 선택해 주세요."
            return
        }
        guard let birthday, let sex, let stage else { return }
        let cancer: SignupSubmission.Cancer
        if usesOtherCancer { cancer = .other(AuthFormValidation.trimmed(otherCancer)) }
        else if let cancerType { cancer = .listed(cancerType) }
        else { return }
        let submittedStage: SignupSubmission.Stage
        switch stage {
        case .known(let value): submittedStage = .known(value)
        case .unknown: submittedStage = .unknown
        case .other: submittedStage = .other(AuthFormValidation.trimmed(otherStage))
        }
        let submission = SignupSubmission(email: AuthFormValidation.trimmed(email), password: password,
                                          name: AuthFormValidation.trimmed(name), birthday: birthday, sex: sex,
                                          cancer: cancer, stage: submittedStage, doctorCode: verifiedCode,
                                          acceptedTerms: acceptedTerms)
        let id = beginRequest()
        defer { if requestID == id { isWorking = false } }
        do {
            try await signUp(submission)
            guard requestID == id, !Task.isCancelled else { return }
            password = ""
            passwordConfirmation = ""
            move(to: .completion)
        } catch {
            guard requestID == id, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = AuthPresentationError.message(for: error, fallback: "가입을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    func cancel() { requestID = UUID(); isWorking = false; errorMessage = nil }
    private func beginRequest() -> UUID {
        let id = UUID()
        requestID = id
        isWorking = true
        return id
    }
    private func move(to step: SignupStep) {
        self.step = step
        hasAttemptedStep = false
        errorMessage = nil
    }
}
