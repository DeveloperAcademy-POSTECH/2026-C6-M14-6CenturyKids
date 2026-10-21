#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 표시 값·입력과 버튼 이벤트만 정의합니다. 인증·검증·요청 취소는 같은 Auth 폴더의 ViewModel이 담당합니다.
@Observable final class LoginScreenState {
    var email = ""
    var password = ""
    var emailError: String?
    var passwordError: String?
    var errorMessage: String?
    var isSubmitting = false
    var didSignIn = false
    var remembersLogin = false
    @ObservationIgnored var onSubmit: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class PasswordResetScreenState {
    var email = ""
    var emailError: String?
    var errorMessage: String?
    var isSubmitting = false
    var didSend = false
    var newPassword = ""
    var passwordConfirmation = ""
    var passwordError: String?
    var isRecoveryReady = false
    var didUpdatePassword = false
    var needsSessionCleanup = false
    @ObservationIgnored var onSubmit: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
struct SignupDoctorConnection {
    let hospitalName: String
    let department: String?
    let doctorName: String
}
enum SignupAction {
    case next, back, verifyDoctorCode, skipDoctorCode, changeDoctorCode
    case editBasicInfo, editDiagnosis, submit, cancel, resendConfirmation
}
@Observable final class SignupScreenState {
    var step: SignupStep = .role
    var isPatient = true
    var name = ""
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var passwordMatches: Bool { !password.isEmpty && password == passwordConfirmation }
    var acceptedTerms: Set<SignupTerm> = []
    var doctorCode = ""
    var connection: SignupDoctorConnection?
    var birthday: Date?
    var sex: Sex?
    var cancerType: CarcinomaType?
    var usesOtherCancer = false
    var otherCancer = ""
    var cancerSearch = ""
    var stage: SignupStageChoice?
    var otherStage = ""
    /// 계정 생성이 시작되면 당시 입력을 고정합니다. 재시도가 다른 사람의 정보로 이어지지 않게 합니다.
    var hasAuthenticatedAccount = false
    var isEmailAlreadyRegistered = false
    var isAccountLocked = false
    var isAwaitingEmailConfirmation = false
    var isWorking = false
    var errorMessage: String?
    var hasAttemptedStep = false
    var currentValidationError: String?
    var termsContent: [SignupTerm: String] = [:]
    var termsVersion: String?
    var termsEffectiveDate: String?
    var hasRequiredTermsContent = false
    var canProceedFromTerms: Bool { hasRequiredTermsContent && allTermsAccepted }
    var age: Int? {
        guard let birthday else { return nil }
        return calendar.dateComponents([.year], from: calendar.startOfDay(for: birthday), to: calendar.startOfDay(for: latestBirthday)).year
    }
    var latestBirthday = Date()
    var calendar = Calendar.current
    var locale = Locale(identifier: "ko_KR")
    @ObservationIgnored var onAction: ((SignupAction) -> Void)?
    var allTermsAccepted: Bool { SignupTerm.allCases.allSatisfy { acceptedTerms.contains($0) } }
    var birthdayText: String? {
        guard let birthday else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: birthday)
    }
    var filteredCancerTypes: [CarcinomaType] {
        CarcinomaType.allCases.filter { cancerSearch.isEmpty || $0.displayName.localizedCaseInsensitiveContains(cancerSearch) }
    }
    var cancerTitle: String { usesOtherCancer ? otherCancer : cancerType?.displayName ?? "선택 전" }
    var stageTitle: String {
        switch stage { case .known(let value): value.displayName; case .unknown: "잘 모르겠어요"; case .other: otherStage; case nil: "선택 전" }
    }
}
extension CarcinomaType { var title: String { displayName } }
extension CarcinomaStage { var title: String { displayName } }
extension Sex { var title: String { displayName } }
