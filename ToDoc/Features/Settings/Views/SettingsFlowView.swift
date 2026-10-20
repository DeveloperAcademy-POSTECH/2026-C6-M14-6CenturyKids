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
         notifications: @escaping @MainActor () -> NotificationSettingsView = {
             NotificationSettingsView()
         }) {
        viewModel = nil
        _state = State(initialValue: state); self.personal = personal; self.cancer = cancer
        self.stage = stage; self.hospital = hospital; self.notifications = notifications
    }

    init(
        viewModel: SettingsViewModel,
        notifications: @escaping @MainActor () -> NotificationSettingsView = {
            NotificationSettingsView()
        }
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
            SettingsView(state: state, onPersonalInfo: { path.append(.personal) }, onCancerType: { path.append(.cancer) },
                         onCancerStage: { path.append(.stage) }, onHospital: { path.append(.hospital) }, notificationSettings: notifications)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .personal: personal()
                    case .cancer: cancer()
                    case .stage: stage()
                    case .hospital: hospital()
                    }
                }
        }
    }
}
#Preview { SettingsFlowView() }
