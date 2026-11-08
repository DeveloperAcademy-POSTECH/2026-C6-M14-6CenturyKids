import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var state: SettingsScreenState
    @State private var showsLogoutConfirmation = false
    @State private var selectedDocument: LegalDocument?
    @State private var showsSupportError = false
    #if DEBUG
    @State private var showsLiveActivityError = false
    @State private var liveActivityErrorMessage = ""
    #endif
    private let onPersonalInfo: (() -> Void)?
    private let onCancerType: (() -> Void)?
    private let onCancerStage: (() -> Void)?
    private let onHospital: (() -> Void)?
    private let onPasswordChange: (() -> Void)?
    private let notificationSettings: @MainActor () -> NotificationSettingsView
    init(state: SettingsScreenState? = nil, onPersonalInfo: (() -> Void)? = nil,
         onCancerType: (() -> Void)? = nil, onCancerStage: (() -> Void)? = nil,
         onHospital: (() -> Void)? = nil,
         onPasswordChange: (() -> Void)? = nil,
         notificationSettings: @escaping @MainActor () -> NotificationSettingsView) {
        _state = State(initialValue: state ?? .init()); self.onPersonalInfo = onPersonalInfo
        self.onCancerType = onCancerType; self.onCancerStage = onCancerStage; self.onHospital = onHospital
        self.onPasswordChange = onPasswordChange
        self.notificationSettings = notificationSettings
    }
    var body: some View {
        GeometryReader { geometry in
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
                    SettingsSection(title: "계정") {
                        NavigationLink { notificationSettings() } label: {
                            SettingsRow(title: "알림 설정", chevron: true)
                        }
                        SettingsDivider()
                        Button { onPasswordChange?() } label: {
                            SettingsRow(title: "비밀번호 재설정", chevron: true)
                        }
                        .disabled(onPasswordChange == nil)
                        .accessibilityIdentifier("settings.password.change")
                    }
                    SettingsSection(title: "기타") {
                        Button(action: openCustomerSupport) {
                            SettingsRow(title: "고객지원", chevron: true)
                        }
                        .accessibilityIdentifier("settings.support")
                        SettingsDivider()
                        Button { selectedDocument = .terms } label: {
                            SettingsRow(title: LegalDocument.terms.title, chevron: true)
                        }
                        .accessibilityIdentifier("settings.terms")
                        SettingsDivider()
                        Button { selectedDocument = .privacy } label: {
                            SettingsRow(title: LegalDocument.privacy.title, chevron: true)
                        }
                        .accessibilityIdentifier("settings.privacy")
                        SettingsDivider()
                        NavigationLink { OpenSourceLicensesView() } label: {
                            SettingsRow(title: "오픈소스 라이선스", chevron: true)
                        }
                        .accessibilityIdentifier("settings.licenses")
                        #if DEBUG
                        SettingsDivider()
                        Button(action: startLocalLiveActivity) {
                            SettingsRow(title: "Live Activity 로컬 실행", chevron: true)
                        }
                        .accessibilityIdentifier("settings.debug.startLiveActivity")
                        .alert("Live Activity를 실행할 수 없어요", isPresented: $showsLiveActivityError) {
                            Button("확인", role: .cancel) {}
                        } message: {
                            Text(liveActivityErrorMessage)
                        }
                        #endif
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        Button { showsLogoutConfirmation = true } label: {
                            Text("로그아웃").foregroundStyle(.black)
                        }
                        .buttonStyle(.glass)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(state.isSigningOut || state.onLogout == nil)
                        .accessibilityIdentifier("settings.logout")
                        .alert("로그아웃 하시겠습니까?", isPresented: $showsLogoutConfirmation) {
                            Button("취소", role: .cancel) {}
                            Button("로그아웃", role: .destructive) { state.onLogout?() }
                        }
                        if state.isSigningOut || state.logoutErrorMessage != nil {
                            SettingsFeedback(busy: state.isSigningOut, error: state.logoutErrorMessage)
                                .padding(.horizontal, 16)
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 32)
                    .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }.background(SettingsPalette.background.ignoresSafeArea()).foregroundStyle(SettingsPalette.primary)
            .buttonStyle(.plain).toolbar(.hidden, for: .navigationBar)
            .alert("고객지원 페이지를 열 수 없어요", isPresented: $showsSupportError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("잠시 후 다시 시도해 주세요.")
            }
            .sheet(item: $selectedDocument) { document in
                DocumentWebView(title: document.title, address: document.address)
                    .ignoresSafeArea()
            }
            .onAppear { state.onReload?() }
            .onDisappear { state.onCancel?() }
    }
    private func openCustomerSupport() {
        guard let url = URL(string: "https://forms.gle/QhVp3MZ3d7PT3Dav5") else {
            showsSupportError = true
            return
        }
        openURL(url) { accepted in
            showsSupportError = !accepted
        }
    }

    #if DEBUG
    private func startLocalLiveActivity() {
        do {
            try LiveActivityService.startLocalLiveActivity()
        } catch {
            liveActivityErrorMessage = error.localizedDescription
            showsLiveActivityError = true
        }
    }
    #endif

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
#if DEBUG
#Preview {
    NavigationStack {
        SettingsView(
            notificationSettings: {
                NotificationSettingsView(viewModel: NotificationSettingsViewModel.preview())
            }
        )
    }
}
#endif
