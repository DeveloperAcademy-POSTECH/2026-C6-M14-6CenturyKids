import SwiftUI

struct SettingsView: View {
    @State private var state: SettingsScreenState
    @State private var showsPasswordChangeNotice = false
    @State private var showsLogoutConfirmation = false
    private let onPersonalInfo: (() -> Void)?
    private let onCancerType: (() -> Void)?
    private let onCancerStage: (() -> Void)?
    private let onHospital: (() -> Void)?
    private let onPasswordChange: (() -> Void)?
    private let onWithdrawal: (() -> Void)?
    private let notificationSettings: @MainActor () -> NotificationSettingsView
    init(state: SettingsScreenState? = nil, onPersonalInfo: (() -> Void)? = nil,
         onCancerType: (() -> Void)? = nil, onCancerStage: (() -> Void)? = nil,
         onHospital: (() -> Void)? = nil,
         onPasswordChange: (() -> Void)? = nil, onWithdrawal: (() -> Void)? = nil,
         notificationSettings: @escaping @MainActor () -> NotificationSettingsView) {
        _state = State(initialValue: state ?? .init()); self.onPersonalInfo = onPersonalInfo
        self.onCancerType = onCancerType; self.onCancerStage = onCancerStage; self.onHospital = onHospital
        self.onPasswordChange = onPasswordChange
        self.notificationSettings = notificationSettings
        self.onWithdrawal = onWithdrawal
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("마이페이지").settingsText(20, bold: true).frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader).padding(.vertical, 24)
                if let patient = state.profile {
                    Button { onPersonalInfo?() } label: {
                        HStack(spacing: 17) {
                            avatar
                            VStack(alignment: .leading, spacing: 3) {
                                Text(patient.name).settingsText(17)
                                Text("개인 정보").settingsText(14).foregroundStyle(SettingsPalette.caption)
                            }
                            Spacer(minLength: 4)
                            Image("SettingsChevron").resizable().frame(width: 6.8, height: 11.8).accessibilityHidden(true)
                        }.padding(16).frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 26)).contentShape(Rectangle())
                    }.disabled(!state.canEdit || onPersonalInfo == nil).accessibilityIdentifier("settings.personalInfo")
                    SettingsSection(title: "건강 정보") {
                        Button { onCancerType?() } label: { SettingsRow(title: "암종", value: patient.cancerName ?? "미등록", chevron: true) }
                            .disabled(!state.canEdit || onCancerType == nil).accessibilityIdentifier("settings.cancerType")
                        SettingsDivider()
                        Button { onCancerStage?() } label: { SettingsRow(title: "병기", value: patient.stageName ?? "미등록", chevron: true) }
                            .disabled(!state.canEdit || onCancerStage == nil).accessibilityIdentifier("settings.cancerStage")
                    }
                    SettingsSection(title: "병원 정보") {
                        SettingsRow(title: "병원", value: patient.hospitalName ?? "연결된 병원 없음")
                        SettingsDivider()
                        SettingsRow(title: "담당의", value: patient.doctorName.map { "\($0) 선생님" } ?? "없음")
                        SettingsDivider()
                        Button { onHospital?() } label: {
                            SettingsRow(title: "병원 연결 관리", value: patient.doctorName == nil ? "연결 안 됨" : "연결됨", chevron: true, connected: patient.doctorName != nil)
                        }.disabled(!state.canEdit || onHospital == nil).accessibilityIdentifier("settings.hospital")
                    }
                } else {
                    SettingsFeedback(busy: state.isLoading, error: loadMessage)
                    if !state.isLoading {
                        Button("정보 다시 불러오기") { state.onReload?() }
                            .settingsText().foregroundStyle(SettingsPalette.action).frame(minHeight: 44)
                            .disabled(state.onReload == nil).accessibilityIdentifier("settings.reloadProfile")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    SettingsSection(title: "계정") {
                        Button { showsPasswordChangeNotice = true } label: {
                            SettingsRow(title: "비밀번호 재설정", chevron: true)
                        }
                        .disabled(onPasswordChange == nil)
                        .accessibilityIdentifier("settings.password.change")

                        SettingsDivider()

                        Button { showsLogoutConfirmation = true } label: {
                            SettingsRow(title: "로그아웃")
                        }
                        .disabled(state.isSigningOut || state.onLogout == nil)
                        .accessibilityIdentifier("settings.logout")
                        .alert("로그아웃 하시겠습니까?", isPresented: $showsLogoutConfirmation) {
                            Button("취소", role: .cancel) {}
                            Button("로그아웃", role: .destructive) { state.onLogout?() }
                        }
                    }

                    if state.isSigningOut || state.logoutErrorMessage != nil {
                        SettingsFeedback(busy: state.isSigningOut, error: state.logoutErrorMessage)
                            .padding(.horizontal, 16)
                    }
                }
                SettingsSection(title: "기타") {
                    NavigationLink { notificationSettings() } label: { SettingsRow(title: "알림 설정", chevron: true) }
                    SettingsDivider()
                    NavigationLink { OpenSourceLicensesView() } label: { SettingsRow(title: "오픈소스 라이선스", chevron: true) }
                        .accessibilityIdentifier("settings.licenses")
                    SettingsDivider()
                    Button { onWithdrawal?() } label: { SettingsRow(title: "회원 탈퇴", chevron: true) }
                        .disabled(onWithdrawal == nil).accessibilityIdentifier("settings.withdrawal")
                }
            }.padding(.horizontal, 24).padding(.bottom, 32)
        }.background(SettingsPalette.background.ignoresSafeArea()).foregroundStyle(SettingsPalette.primary)
            .buttonStyle(.plain).toolbar(.hidden, for: .navigationBar)
            .alert("비밀번호 변경을 위한 인증코드를 가입한 이메일로 보내드릴게요.", isPresented: $showsPasswordChangeNotice) {
                Button("취소", role: .cancel) {}
                Button("확인") { onPasswordChange?() }
            }
            .onAppear { state.onReload?() }
            .onDisappear { state.onCancel?() }
    }
    private var avatar: some View {
        SettingsProfileAvatar(size: 64)
    }
    private var loadMessage: String? {
        switch state.loadState {
        case .idle, .loading, .loaded: nil
        case .unavailable: "개인정보 조회 연결을 준비 중이에요."
        case .missingProfile: "환자 정보를 찾지 못했어요. 계정 정보를 확인해 주세요."
        case .failed: "정보를 불러오지 못했어요. 다시 시도해 주세요."
        }
    }
}
#Preview {
    NavigationStack {
        SettingsView(
            notificationSettings: {
                NotificationSettingsView(viewModel: NotificationSettingsViewModel())
            }
        )
    }
}
