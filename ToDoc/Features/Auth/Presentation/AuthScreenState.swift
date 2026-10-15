#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 표시 값·입력과 버튼 이벤트만 정의합니다. 인증·검증·요청 취소 정책은 하지의 새 ViewModel에서 구현합니다.
@Observable final class LoginScreenState {
    var email = ""
    var password = ""
    var emailError: String?
    var passwordError: String?
    var errorMessage: String?
    var isSubmitting = false
    var didSignIn = false
    @ObservationIgnored var onSubmit: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class PasswordResetScreenState {
    var email = ""
    var emailError: String?
    var errorMessage: String?
    var isSubmitting = false
    var didSend = false
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
    case editBasicInfo, editDiagnosis, submit, cancel
}
@Observable final class SignupScreenState {
    var step: SignupStep = .role
    var isPatient = true
    var name = ""
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var passwordMatches = false
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
    var isWorking = false
    var errorMessage: String?
    var hasAttemptedStep = false
    var currentValidationError: String?
    var termsContent: [SignupTerm: String] = [:]
    var hasRequiredTermsContent = false
    var age: Int?
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
