import SwiftUI

/// 현재 로그인한 환자를 조회한 뒤 환자 화면의 의존성을 구성합니다.
@MainActor
struct PatientFlowCompositionView: View {
    @State private var viewModel: PatientFlowViewModel
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makePatientFlowViewModel())
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("환자 정보를 불러오는 중이에요.")
            case .loaded(let patientId):
                LoadedPatientFlow(container: container, patientId: patientId)
            case .failed:
                ContentUnavailableView {
                    Label("환자 정보를 불러오지 못했어요", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("로그인 상태를 확인한 뒤 다시 시도해 주세요.")
                } actions: {
                    Button("다시 시도") {
                        Task { await viewModel.loadPatient() }
                    }
                }
            }
        }
        .task {
            await viewModel.loadPatient()
        }
    }
}

@MainActor
private struct LoadedPatientFlow: View {
    @State private var painViewModel: PainRecordViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(container: DependencyContainer, patientId: UUID) {
        _painViewModel = State(
            initialValue: container.makePainRecordViewModel()
        )
        _settingsViewModel = State(
            initialValue: container.makeSettingsViewModel(patientId: patientId)
        )
    }

    var body: some View {
        PatientFlowView(
            pain: { PainRecordView(viewModel: painViewModel) },
            settings: { SettingsFlowView(viewModel: settingsViewModel) }
        )
    }
}
