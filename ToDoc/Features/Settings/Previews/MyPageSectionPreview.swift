#if DEBUG
import SwiftUI
import Observation

/// 마이페이지의 여섯 Figma 화면을 둘러보는 개발 전용 호스트입니다.
/// 변경은 이 Preview 인스턴스 안에서만 유지되며 Repository/인증/알림 권한을 호출하지 않습니다.
struct MyPageSectionPreview: View {
    enum Screen: String, CaseIterable, Hashable {
        case home = "마이페이지"
        case personal = "내 정보 수정"
        case cancer = "암종"
        case stage = "병기"
        case hospitalInfo = "병원 정보 수정 · 디자인 예시"
        case hospitalConnection = "병원 연결 관리"
    }

    @State private var data = MyPagePreviewData()
    @State private var path: [Screen]
    private let showsControls: Bool
    private let focusesTextField: Bool

    init(initialScreen: Screen = .home, showsControls: Bool = true, focusesTextField: Bool = false) {
        _path = State(initialValue: initialScreen == .home ? [] : [initialScreen])
        self.showsControls = showsControls
        self.focusesTextField = focusesTextField
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsControls {
                VStack(spacing: 4) {
                    Text("화면 예시 · 실제 조회와 저장 없음").font(.caption).foregroundStyle(.secondary)
                    Picker("마이페이지 화면", selection: Binding(get: { path.last ?? .home }, set: show)) {
                        ForEach(Screen.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("mypage.preview.screen")
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .background(AppColors.Settings.background)
            }
            NavigationStack(path: $path) {
                SettingsView(
                    state: data.settings,
                    onPersonalInfo: { show(.personal) },
                    onCancerType: { show(.cancer) },
                    onCancerStage: { show(.stage) },
                    onHospital: { show(.hospitalConnection) },
                    showsLicenses: false,
                    notificationSettings: { NotificationSettingsView(state: data.notifications) }
                )
                .navigationDestination(for: Screen.self) { screen in
                    destination(screen)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func show(_ screen: Screen) {
        data.prepare(screen)
        path = screen == .home ? [] : [screen]
    }

    @ViewBuilder private func destination(_ screen: Screen) -> some View {
        switch screen {
        case .home:
            EmptyView()
        case .personal:
            PersonalInfoEditView(state: data.personal, focusesNameOnAppear: focusesTextField)
        case .cancer:
            CancerTypeEditView(state: data.cancer)
        case .stage:
            CancerStageEditView(state: data.stage)
        case .hospitalInfo:
            MyPageHospitalInfoPreviewView(
                hospitalName: data.hospital.doctor?.hospitalName ?? "세명기독병원",
                doctorName: data.hospital.doctor?.name ?? "김학로",
                focusesHospitalOnAppear: focusesTextField
            )
        case .hospitalConnection:
            HospitalConnectionView(state: data.hospital, focusesCodeOnAppear: focusesTextField)
        }
    }
}

/// 실제 병원 변경 계약은 의사 코드입니다. 이름 직접 입력 프레임 1:4006은 Canvas에서만 확인합니다.
private struct MyPageHospitalInfoPreviewView: View {
    @State var hospitalName: String
    @State var doctorName: String
    let focusesHospitalOnAppear: Bool
    @FocusState private var hospitalFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        SettingsScreen(title: "병원 정보 수정", cancelTitle: "취소", canSave: true,
                       save: { dismiss() }, cancel: { dismiss() }) {
            SettingsSection(title: "병원 정보", footer: "병원과 담당의 정보를 확인해 주세요.\n변경한 정보는 완료를 누르면 저장돼요.") {
                SettingsInputRow(title: "치료받는 병원") {
                    TextField("치료받는 병원", text: $hospitalName)
                        .appFont(.settingsRow).foregroundStyle(AppColors.Settings.secondary)
                        .focused($hospitalFocused)
                        .accessibilityIdentifier("mypage.preview.hospitalName")
                }
                SettingsDivider()
                SettingsInputRow(title: "담당의") {
                    HStack(spacing: 4) {
                        TextField("담당의", text: $doctorName)
                            .accessibilityIdentifier("mypage.preview.doctorName")
                        Text("선생님").fixedSize()
                    }
                    .appFont(.settingsRow).foregroundStyle(AppColors.Settings.secondary)
                }
            }
            .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit { hospitalFocused = false }
        }
        .tint(AppColors.Settings.action)
        .onAppear { hospitalFocused = focusesHospitalOnAppear }
    }
}

@MainActor @Observable private final class MyPagePreviewData {
    let settings = SettingsScreenState()
    let personal = PersonalInfoScreenState()
    let cancer = DiagnosisScreenState()
    let stage = DiagnosisScreenState()
    let hospital = HospitalConnectionScreenState()
    let notifications = NotificationSettingsScreenState()
    private var savedName = "최연우"
    private var savedBirthday: Date
    private var savedSex: Sex = .female
    private var savedCancer: CarcinomaType = .lung
    private var savedStage: CarcinomaStage = .stage3

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)!
        savedBirthday = calendar.date(from: DateComponents(year: 2004, month: 9, day: 27))!
        personal.calendar = calendar
        settings.profile = .init(name: savedName, cancerName: "폐암", stageName: "3기",
                                 hospitalName: "세명기독병원", doctorName: "김학로")
        settings.loadState = .loaded
        settings.canEdit = true
        hospital.doctor = .init(hospitalName: "세명기독병원", name: "김학로")
        hospital.code = "Rh3bu0"
        hospital.hasLoaded = true
        hospital.canVerify = true
        hospital.canDisconnect = true
        personal.canSave = true
        cancer.canSave = true
        stage.canSave = true

        personal.onSave = { [weak self] in
            guard let self else { return }
            let name = self.personal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { self.personal.validationMessage = "이름을 입력해 주세요."; return }
            self.savedName = name
            self.savedBirthday = self.personal.birthday
            self.savedSex = self.personal.sex
            self.settings.profile?.name = name
            self.personal.validationMessage = nil
            self.personal.didSave = true
        }
        cancer.onSave = { [weak self] in
            guard let self, case .carcinoma(let value) = self.cancer.selection else { return }
            self.savedCancer = value
            self.settings.profile?.cancerName = value.displayName
            self.cancer.didSave = true
        }
        stage.onSave = { [weak self] in
            guard let self, case .stage(let value) = self.stage.selection else { return }
            self.savedStage = value
            self.settings.profile?.stageName = value.displayName
            self.stage.didSave = true
        }
        hospital.onAction = { [weak self] action in self?.handleHospital(action) }
        notifications.hasLoaded = true
        notifications.authorization = .authorized
        notifications.canEdit = true
        notifications.preferences = [.init(id: "carecall", title: "케어콜 알림", isEnabled: true),
                                     .init(id: "pain", title: "복용 후 통증 기록 알림", isEnabled: true)]
        notifications.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .setEnabled(let id, let enabled):
                guard let index = self.notifications.preferences.firstIndex(where: { $0.id == id }) else { return }
                self.notifications.preferences[index].isEnabled = enabled
                self.notifications.hasChanges = true
                self.notifications.canSave = true
                self.notifications.didSave = false
            case .save:
                self.notifications.hasChanges = false
                self.notifications.didSave = true
            case .discardChanges:
                self.notifications.preferences.indices.forEach { self.notifications.preferences[$0].isEnabled = true }
                self.notifications.hasChanges = false
            case .load, .requestAuthorization, .refreshAuthorization, .cancel: break
            }
        }
        prepare(.personal)
        prepare(.cancer)
        prepare(.stage)
    }

    func prepare(_ screen: MyPageSectionPreview.Screen) {
        switch screen {
        case .personal:
            personal.name = savedName
            personal.birthday = savedBirthday
            personal.sex = savedSex
            personal.didSave = false
            personal.validationMessage = nil
        case .cancer:
            cancer.selection = .carcinoma(savedCancer)
            cancer.didSave = false
        case .stage:
            stage.selection = .stage(savedStage)
            stage.didSave = false
        case .home, .hospitalInfo, .hospitalConnection: break
        }
    }

    private func handleHospital(_ action: HospitalConnectionAction) {
        switch action {
        case .load, .cancel: break
        case .verify:
            guard hospital.code.trimmingCharacters(in: .whitespacesAndNewlines) == "Rh3bu0" else {
                hospital.candidate = nil
                hospital.errorMessage = "Preview에서는 예시 코드 Rh3bu0을 사용해 주세요."
                return
            }
            hospital.errorMessage = nil
            hospital.candidate = .init(hospitalName: "세명기독병원", name: "김학로")
            hospital.canConnect = hospital.doctor == nil
        case .connect:
            guard let candidate = hospital.candidate else { return }
            hospital.doctor = candidate
            hospital.candidate = nil
            hospital.canDisconnect = true
            settings.profile?.hospitalName = candidate.hospitalName
            settings.profile?.doctorName = candidate.name
        case .disconnect:
            hospital.doctor = nil
            hospital.candidate = nil
            hospital.canDisconnect = false
            settings.profile?.hospitalName = nil
            settings.profile?.doctorName = nil
        }
    }
}

#Preview("마이페이지 · 화면 모음") { MyPageSectionPreview() }
#Preview("1:3627 · 마이페이지") { MyPageSectionPreview(showsControls: false) }
#Preview("1:3697 · 내 정보 수정") { MyPageSectionPreview(initialScreen: .personal, showsControls: false) }
#Preview("1:3795 · 암종") { MyPageSectionPreview(initialScreen: .cancer, showsControls: false) }
#Preview("1:3851 · 병기") { MyPageSectionPreview(initialScreen: .stage, showsControls: false) }
#Preview("1:4006 · 병원 정보 디자인 예시") { MyPageSectionPreview(initialScreen: .hospitalInfo, showsControls: false) }
#Preview("1:4101 · 병원 연결 관리") { MyPageSectionPreview(initialScreen: .hospitalConnection, showsControls: false) }
#Preview("내 정보 · 입력 중") { MyPageSectionPreview(initialScreen: .personal, showsControls: false, focusesTextField: true) }
#Preview("마이페이지 · 큰 글자") { MyPageSectionPreview().environment(\.dynamicTypeSize, .accessibility3) }
#endif
