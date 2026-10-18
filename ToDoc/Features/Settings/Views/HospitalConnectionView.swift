import SwiftUI

struct HospitalConnectionView: View {
    @State private var state: HospitalConnectionScreenState?
    @State private var confirmsConnection = false
    @State private var confirmsDisconnect = false
    @FocusState private var codeFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    private let title: String
    private let focusesCodeOnAppear: Bool
    init(state: HospitalConnectionScreenState? = nil, title: String = "병원 연결 관리", focusesCodeOnAppear: Bool = false) {
        _state = State(initialValue: state); self.title = title
        self.focusesCodeOnAppear = focusesCodeOnAppear
    }
    var body: some View {
        SettingsScreen(title: title, canSave: state?.isBusy == false, save: { codeFocused = false; dismiss() }, cancel: { dismiss() }) {
            if let state {
                if state.hasLoaded {
                    SettingsSection(title: "연결된 병원") {
                        SettingsRow(title: "병원", value: state.doctor?.hospitalName ?? "연결된 병원 없음")
                        SettingsDivider()
                        SettingsRow(title: "담당의", value: state.doctor.map { "\($0.name) 선생님" } ?? "없음")
                        SettingsDivider()
                        SettingsRow(title: "연결 상태", value: state.doctor == nil ? "연결 안 됨" : "연결됨", connected: state.doctor != nil)
                    }
                    SettingsSection(title: "담당의 등록", footer: "병원에서 받은 코드로 연결 정보를 변경할 수 있어요.") {
                        SettingsInputRow(title: "의사 코드") {
                            TextField("의사 코드", text: Binding(get: { state.code }, set: { state.code = $0 }))
                                .appFont(.settingsRow).foregroundStyle(AppColors.Settings.secondary).multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                                .focused($codeFocused)
                                .disabled(state.isBusy).accessibilityIdentifier("settings.doctorCode")
                                .onSubmit { state.onAction?(.verify) }
                        }
                        SettingsDivider()
                        Button { state.onAction?(.verify) } label: { SettingsRow(title: "연결 정보 확인", chevron: true) }
                            .disabled(!state.canVerify || state.onAction == nil).accessibilityIdentifier("settings.verifyDoctor")
                    }
                    if let candidate = state.candidate {
                        // 연결 대상 확인 상태는 하이파이 대기: 기본 정보와 버튼으로만 표시합니다.
                        SettingsSection(title: "연결할 의료진") {
                            SettingsRow(title: "병원", value: candidate.hospitalName)
                            SettingsDivider()
                            SettingsRow(title: "담당의", value: "\(candidate.name) 선생님")
                            SettingsDivider()
                            Button { confirmsConnection = true } label: {
                                SettingsRow(title: state.canConnect ? "이 의료진으로 연결" : "이미 연결된 의료진이에요")
                            }.foregroundStyle(AppColors.Settings.action).disabled(!state.canConnect || state.onAction == nil)
                                .accessibilityIdentifier("settings.connectDoctor")
                        }
                    }
                    if state.doctor != nil {
                        Button(role: .destructive) { confirmsDisconnect = true } label: {
                            Text("병원 연결 해제").appFont(.settingsRow).frame(maxWidth: .infinity).padding(.vertical, AppSpacing.content)
                                .appSurface(.settingsGroup)
                        }.foregroundStyle(AppColors.Feedback.destructive).disabled(!state.canDisconnect || state.onAction == nil).padding(.top, 20)
                            .accessibilityIdentifier("settings.disconnectDoctor")
                    }
                }
                SettingsFeedback(busy: state.isBusy, error: state.errorMessage, success: state.successMessage)
                if !state.hasLoaded && !state.isBusy {
                    Button("연결 정보 다시 불러오기") { state.onAction?(.load) }
                        .appFont(.settingsRow).foregroundStyle(AppColors.Settings.action).frame(minHeight: AppMetrics.Control.minimumHitSize)
                        .accessibilityIdentifier("settings.reloadConnection")
                }
            } else { Text("환자 정보를 먼저 불러와 주세요.").appFont(.settingsRow) }
        }
        .onAppear { state?.onAction?(.load); codeFocused = focusesCodeOnAppear }
        .alert("이 의료진으로 연결할까요?", isPresented: $confirmsConnection) {
            Button("취소", role: .cancel) {}
            Button("연결") { if let state { state.onAction?(.connect) } }
        } message: {
            if let candidate = state?.candidate { Text("\(candidate.hospitalName) · \(candidate.name) 선생님") }
        }
        .alert("병원 연결을 해제할까요?", isPresented: $confirmsDisconnect) {
            Button("취소", role: .cancel) {}
            Button("연결 해제", role: .destructive) { if let state { state.onAction?(.disconnect) } }
        } message: { Text("연결을 해제해도 혼자서 앱을 계속 이용할 수 있어요.") }
        .onDisappear { state?.onAction?(.cancel) }
    }
 }
#Preview("미연결") { NavigationStack { HospitalConnectionView() } }
