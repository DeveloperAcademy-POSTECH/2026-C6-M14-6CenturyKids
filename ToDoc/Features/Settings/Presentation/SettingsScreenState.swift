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
    @ObservationIgnored var onSave: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
@Observable final class DiagnosisScreenState {
    var selection: DiagnosisChange?
    var isSaving = false
    var canSave = false
    var didSave = false
    var errorMessage: String?
    @ObservationIgnored var onSave: (() -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
enum HospitalConnectionAction { case load, verify, connect, disconnect, cancel }
@Observable final class HospitalConnectionScreenState {
    var doctor: DoctorDisplayData?
    var candidate: DoctorDisplayData?
    var code = ""
    var hasLoaded = false
    var isBusy = false
    var canVerify = false
    var canConnect = false
    var canDisconnect = false
    var errorMessage: String?
    var successMessage: String?
    @ObservationIgnored var onAction: ((HospitalConnectionAction) -> Void)?
}
struct NotificationPreference: Identifiable {
    let id: String
    let title: String
    var isEnabled: Bool
}
enum NotificationSettingsAction {
    case load, save, discardChanges, requestAuthorization, refreshAuthorization, cancel
    case setEnabled(String, Bool)
}
@Observable final class NotificationSettingsScreenState {
    var authorization: NotificationAuthorization?
    var preferences: [NotificationPreference] = []
    var hasLoaded = false
    var didSave = false
    var errorMessage: String?
    var isBusy = false
    var hasChanges = false
    var canEdit = false
    var canSave = false
    var canRequestAuthorization = false
    var canOpenSettings = false
    @ObservationIgnored var onAction: ((NotificationSettingsAction) -> Void)?
}
