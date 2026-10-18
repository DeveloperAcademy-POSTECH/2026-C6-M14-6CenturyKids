import SwiftUI

/// 독립 하이파이 디자인 대기. 상태/연결 확인용 기본 컨트롤만 사용합니다.
/// 시스템 Form의 글꼴·보조색은 네이티브 컨트롤의 현재 외형을 유지합니다.
struct NotificationSettingsView: View {
    @State private var state: NotificationSettingsScreenState
    @Environment(\.scenePhase) private var scenePhase
    private let openSettings: (() -> Void)?

    init(state: NotificationSettingsScreenState? = nil, openSettings: (() -> Void)? = nil) {
        _state = State(initialValue: state ?? .init()); self.openSettings = openSettings
    }
    var body: some View {
        Form {
            Section { Text(state.onAction == nil ? "알림 설정 기능 연결 전이에요." : "알림 수신 설정").font(.caption).foregroundStyle(.secondary) }
            Section("시스템 알림 권한") {
                LabeledContent("현재 상태", value: state.authorization?.displayName ?? "확인 전")
                if state.canRequestAuthorization {
                    Button("알림 권한 요청") { state.onAction?(.requestAuthorization) }
                }
                if state.canOpenSettings {
                    Button("기기 설정 열기") { openSettings?() }.disabled(openSettings == nil)
                }
                if state.hasLoaded {
                    Button("권한 상태 새로고침") { state.onAction?(.refreshAuthorization) }.disabled(state.isBusy || state.onAction == nil)
                }
            }
            Section("앱 수신 설정") {
                if state.preferences.isEmpty {
                    Text(state.hasLoaded ? "제공된 설정 항목이 없어요." : "설정 항목을 불러와 주세요.")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.preferences) { preference in
                    Toggle(preference.title, isOn: Binding(get: {
                        state.preferences.first { $0.id == preference.id }?.isEnabled ?? false
                    }, set: { state.onAction?(.setEnabled(preference.id, $0)) }))
                        .disabled(!state.canEdit || state.onAction == nil).accessibilityIdentifier("notification.preference.\(preference.id)")
                }
            }
            Section {
                if state.isBusy { ProgressView("처리 중") }
                if let error = state.errorMessage { Text(error).foregroundStyle(AppColors.Feedback.error) }
                if state.didSave { Text("설정을 저장했어요.") }
                if state.hasChanges {
                    Button("설정 저장") { state.onAction?(.save) }.disabled(!state.canSave || state.onAction == nil)
                    Button("변경 취소") { state.onAction?(.discardChanges) }.disabled(state.isBusy || state.onAction == nil)
                } else if !state.hasLoaded || state.errorMessage != nil {
                    Button("설정 다시 불러오기") { state.onAction?(.load) }.disabled(state.isBusy || state.onAction == nil)
                }
            }
        }
        .navigationTitle("알림 설정 · 임시").navigationBarTitleDisplayMode(.inline)
        .onAppear { state.onAction?(.load) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state.onAction?(.refreshAuthorization) }
        }
        .onDisappear { state.onAction?(.cancel) }
    }
 }
#Preview("미연결") { NavigationStack { NotificationSettingsView() } }
