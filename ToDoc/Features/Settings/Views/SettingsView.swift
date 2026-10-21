import SwiftUI

struct SettingsView: View {
    @State private var state: SettingsScreenState
    private let onPersonalInfo: (() -> Void)?
    private let onCancerType: (() -> Void)?
    private let onCancerStage: (() -> Void)?
    private let onHospital: (() -> Void)?
    private let notificationSettings: @MainActor () -> NotificationSettingsView
    init(state: SettingsScreenState? = nil, onPersonalInfo: (() -> Void)? = nil,
         onCancerType: (() -> Void)? = nil, onCancerStage: (() -> Void)? = nil,
         onHospital: (() -> Void)? = nil,
         notificationSettings: @escaping @MainActor () -> NotificationSettingsView) {
        _state = State(initialValue: state ?? .init()); self.onPersonalInfo = onPersonalInfo
        self.onCancerType = onCancerType; self.onCancerStage = onCancerStage; self.onHospital = onHospital
        self.notificationSettings = notificationSettings
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("마이페이지").settingsText(32, bold: true).accessibilityAddTraits(.isHeader).padding(.top, 20)
                if let patient = state.profile {
                    Button { onPersonalInfo?() } label: {
                        HStack(spacing: 17) {
                            avatar
                            VStack(alignment: .leading, spacing: 3) {
                                Text(patient.name).settingsText(21)
                                Text("개인 정보").settingsText(14).foregroundStyle(SettingsPalette.caption)
                            }
                            Spacer(minLength: 4)
                            Image("SettingsChevron").resizable().frame(width: 6.8, height: 11.8).accessibilityHidden(true)
                        }.padding(20).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14)).contentShape(Rectangle())
                    }.disabled(!state.canEdit || onPersonalInfo == nil).accessibilityIdentifier("settings.personalInfo")
                    SettingsSection(title: "건강 정보") {
                        Button { onCancerType?() } label: { SettingsRow(title: "암종", value: patient.cancerName ?? "미등록", chevron: true) }
                            .disabled(!state.canEdit || onCancerType == nil).accessibilityIdentifier("settings.cancerType")
                        SettingsDivider()
                        Button { onCancerStage?() } label: { SettingsRow(title: "병기", value: patient.stageName ?? "미등록", chevron: true) }
                            .disabled(!state.canEdit || onCancerStage == nil).accessibilityIdentifier("settings.cancerStage")
                    }
                    SettingsSection(title: "병원 정보") {
                        SettingsRow(title: "치료받는 병원", value: patient.hospitalName ?? "연결된 병원 없음")
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
                SettingsSection(title: "기타") {
                    NavigationLink { notificationSettings() } label: { SettingsRow(title: "알림 설정", chevron: true) }
                    SettingsDivider()
                    NavigationLink { OpenSourceLicensesView() } label: { SettingsRow(title: "라이선스", chevron: true) }
                        .accessibilityIdentifier("settings.licenses")
                }
            }.padding(.horizontal, 20).padding(.bottom, 32)
        }.background(SettingsPalette.background.ignoresSafeArea()).foregroundStyle(SettingsPalette.primary)
            .buttonStyle(.plain).toolbar(.hidden, for: .navigationBar)
            .onAppear { state.onReload?() }
            .onDisappear { state.onCancel?() }
    }
    private var avatar: some View {
        ZStack(alignment: .topLeading) {
            Image("SettingsAvatarCircle").resizable().frame(width: 52, height: 52)
            Image("SettingsAvatarHead").resizable().frame(width: 16, height: 16).offset(x: 18, y: 11)
            Image("SettingsAvatarBody").resizable().frame(width: 32, height: 16).offset(x: 10, y: 26)
        }.frame(width: 52, height: 52).accessibilityHidden(true)
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
