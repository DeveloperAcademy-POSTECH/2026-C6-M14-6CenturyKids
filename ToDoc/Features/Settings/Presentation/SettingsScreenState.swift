import Foundation
import Observation

struct ProfileDisplayData {
    var name: String
    var cancerName: String?
    var stageName: String?
    var hospitalName: String?
    var doctorName: String?
}
struct DoctorDisplayData {
    let hospitalName: String
    let name: String
}
@Observable final class SettingsScreenState {
    var profile: ProfileDisplayData?
    var loadState: SettingsLoadState = .unavailable
    var isLoading = false
    var canEdit = false
    var isSigningOut = false
    var logoutErrorMessage: String?
    @ObservationIgnored var onLogout: (() -> Void)?
    @ObservationIgnored var onReload: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class PersonalInfoScreenState {
    var name = ""
    var birthday = Date()
    var sex: Sex = .female
    var calendar = Calendar.current
    var canSave = false
    var isSaving = false
    var didSave = false
    var validationMessage: String?
    var errorMessage: String?
    @ObservationIgnored var onLoad: (() -> Void)?
    @ObservationIgnored var onSave: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class PasswordChangeScreenState {
    var verificationCode = ""
    var codeError: String?
    var isSendingCode = false
    var hasSentCode = false
    var newPassword = ""
    var passwordConfirmation = ""
    var newPasswordError: String?
    var confirmationError: String?
    var isSaving = false
    var didSave = false
    var errorMessage: String?
    @ObservationIgnored var onSendCode: (() -> Void)?
    @ObservationIgnored var onSave: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class DiagnosisScreenState {
    var selection: DiagnosisChange?
    var customCancerName = ""
    var isSaving = false
    var canSave = false
    var canSaveCustomCancer: Bool {
        !isSaving && CarcinomaType(name: customCancerName) != nil
    }
    var didSave = false
    var errorMessage: String?
    @ObservationIgnored var onLoad: (() -> Void)?
    @ObservationIgnored var onSave: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
    @ObservationIgnored var onBeginCustomCancer: (() -> Void)?
    @ObservationIgnored var onSaveCustomCancer: (() -> Void)?
    @ObservationIgnored var onCancelCustomCancer: (() -> Void)?
}
enum HospitalConnectionAction { case load, verify, connect, disconnect, cancel }
@Observable final class HospitalConnectionScreenState {
    var doctor: DoctorDisplayData?
    var candidate: DoctorDisplayData?
    var candidateDoctorId: UUID?
    var code = "" {
        didSet {
            guard code != oldValue else { return }
            candidate = nil
            candidateDoctorId = nil
            canConnect = false
            errorMessage = nil
            successMessage = nil
        }
    }
    var hasLoaded = false
    var isBusy = false
    var canVerify: Bool {
        hasLoaded &&
        !isBusy &&
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var canConnect = false
    var canDisconnect = false
    var errorMessage: String?
    var successMessage: String?
    @ObservationIgnored var onAction: ((HospitalConnectionAction) -> Void)?
}
