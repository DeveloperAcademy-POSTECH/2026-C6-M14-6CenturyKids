import SwiftUI

/// 목적지 View를 주입하는 화면 이동 경계입니다. 조회와 저장은 외부 담당자가 연결합니다.
struct SettingsFlowView: View {
    private let viewModel: SettingsViewModel?
    @State private var state: SettingsScreenState
    @State private var path: [Destination] = []
    var personal: () -> PersonalInfoEditView
    var cancer: () -> CancerTypeEditView
    var stage: () -> CancerStageEditView
    var hospital: () -> HospitalConnectionView
    var notifications: @MainActor () -> NotificationSettingsView
    init(state: SettingsScreenState = .init(), personal: @escaping () -> PersonalInfoEditView = { .init() },
         cancer: @escaping () -> CancerTypeEditView = { .init() }, stage: @escaping () -> CancerStageEditView = { .init() },
         hospital: @escaping () -> HospitalConnectionView = { .init() },
         notifications: @escaping @MainActor () -> NotificationSettingsView) {
        viewModel = nil
        _state = State(initialValue: state); self.personal = personal; self.cancer = cancer
        self.stage = stage; self.hospital = hospital; self.notifications = notifications
    }

    init(
        viewModel: SettingsViewModel,
        notifications: @escaping @MainActor () -> NotificationSettingsView
    ) {
        self.viewModel = viewModel
        _state = State(initialValue: viewModel.screenState)
        personal = { PersonalInfoEditView(state: viewModel.personalInfoState) }
        cancer = { CancerTypeEditView(state: viewModel.carcinomaState) }
        stage = { CancerStageEditView(state: viewModel.stageState) }
        hospital = { HospitalConnectionView(state: viewModel.hospitalConnectionState) }
        self.notifications = notifications
    }

    var body: some View {
        NavigationStack(path: $path) {
            settingsRoot
                .navigationDestination(for: Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .onChange(of: viewModel?.passwordChangeState.didSave, handlePasswordSaved)
        .onChange(of: viewModel?.passwordChangeState.codeError, handlePasswordCodeError)
        .onChange(of: path, handlePathChange)
    }

    private var settingsRoot: some View {
        SettingsView(
            state: state,
            onPersonalInfo: { path.append(.personal) },
            onCancerType: { path.append(.cancer) },
            onCancerStage: { path.append(.stage) },
            onHospital: { path.append(.hospital) },
            onPasswordChange: passwordChangeAction,
            notificationSettings: notifications
        )
    }

    private var passwordChangeAction: (() -> Void)? {
        guard viewModel != nil else { return nil }
        return { startPasswordChange() }
    }

    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .personal: personal()
        case .cancer: cancer()
        case .stage: stage()
        case .hospital: hospital()
        case .passwordCode:
            if let viewModel {
                PasswordCodeEntryView(state: viewModel.passwordChangeState) {
                    path.append(.newPassword)
                }
            }
        case .newPassword:
            if let viewModel {
                NewPasswordEntryView(state: viewModel.passwordChangeState)
            }
        }
    }

    private func handlePasswordSaved(_ oldValue: Bool?, _ didSave: Bool?) {
        if didSave == true { path = [] }
    }

    private func handlePasswordCodeError(_ oldValue: String?, _ codeError: String?) {
        if codeError != nil && path.last == .newPassword { path.removeLast() }
    }

    private func handlePathChange(_ oldPath: [Destination], _ newPath: [Destination]) {
        let wasInPasswordChange = oldPath.contains(.passwordCode) || oldPath.contains(.newPassword)
        let isInPasswordChange = newPath.contains(.passwordCode) || newPath.contains(.newPassword)
        if wasInPasswordChange && !isInPasswordChange && viewModel?.passwordChangeState.didSave != true {
            viewModel?.passwordChangeState.onCancel?()
        }
    }

    private func startPasswordChange() {
        guard let viewModel else { return }

        viewModel.discardPasswordChange()
        path.append(.passwordCode)
        viewModel.passwordChangeState.onSendCode?()
    }
}
#Preview {
    SettingsFlowView(
        notifications: { NotificationSettingsView(viewModel: NotificationSettingsViewModel()) }
    )
}
