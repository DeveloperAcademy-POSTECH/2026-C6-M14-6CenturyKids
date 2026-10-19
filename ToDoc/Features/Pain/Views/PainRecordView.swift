import SwiftUI

/// View는 입력과 페이지 이동을 담당하고, ViewModel에서 기록을 준비합니다.
struct PainRecordView: View {
    let viewModel: PainRecordViewModel?
    @State private var loadedViewModel: PainRecordViewModel? = nil
    @State private var connectionState = ConnectionState.loading
    @State private var state: PainScreenState
    @State private var step = 0
    @State private var didStartRecord = false
    @State private var activeAlert: PainRecordAlert?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    var onClose: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

    private enum ConnectionState {
        case loading
        case signedOut
        case patientUnavailable
        case failed
    }

    private var activeViewModel: PainRecordViewModel? {
        viewModel ?? loadedViewModel
    }

    private enum PainRecordAlert: String, Identifiable {
        case recordAgainFailed
        case saveFailed

        var id: Self { self }

        var title: String {
            switch self {
            case .recordAgainFailed: "다시 기록할 수 없어요"
            case .saveFailed: "기록을 저장하지 못했어요"
            }
        }
    }

    /// 기존 호출을 유지하고 화면이 나타난 뒤 로그인 환자의 ViewModel을 준비합니다.
    init() {
        self.viewModel = nil
        _state = State(initialValue: PainScreenState())
        self.onClose = nil
        self.onShowRecord = nil
        self.onHome = nil
        self.onCancel = nil
    }

    init(viewModel: PainRecordViewModel, state: PainScreenState = PainScreenState(),
         onClose: (() -> Void)? = nil, onShowRecord: (() -> Void)? = nil,
         onHome: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.viewModel = viewModel
        _state = State(initialValue: state)
        self.onClose = onClose; self.onShowRecord = onShowRecord
        self.onHome = onHome; self.onCancel = onCancel
    }
    var body: some View {
        Group {
            if let viewModel = activeViewModel {
                recordContent(viewModel: viewModel)
            } else {
                switch connectionState {
                case .loading:
                    ProgressView("통증 기록을 준비하고 있어요")
                case .signedOut:
                    ContentUnavailableView("로그인이 필요해요", systemImage: "person.crop.circle",
                                           description: Text("통증 기록을 이용하려면 로그인해 주세요."))
                case .patientUnavailable:
                    ContentUnavailableView("환자 계정을 찾지 못했어요", systemImage: "person.crop.circle.badge.questionmark")
                case .failed:
                    ContentUnavailableView {
                        Label("통증 기록을 열 수 없어요", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("잠시 후 다시 시도해 주세요.")
                    } actions: {
                        Button("다시 시도") {
                            Task { await loadViewModelIfNeeded() }
                        }
                    }
                }
            }
        }
        .task { await loadViewModelIfNeeded() }
        .onAppear { startRecordIfNeeded() }
        .onDisappear { onCancel?() }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text("잠시 후 다시 시도해 주세요."),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    @MainActor
    private func loadViewModelIfNeeded() async {
        guard activeViewModel == nil else { return }
        guard let container else {
            connectionState = .failed
            return
        }

        connectionState = .loading
        let client = container.supabaseProvider.client
        let authRepository = SupabaseAuthRepository(client: client)

        do {
            let userId = try await authRepository.getCurrentUserId()
            guard !Task.isCancelled else { return }
            guard let patient = try await SupabasePatientRepository(client: client).findById(userId) else {
                connectionState = .patientUnavailable
                return
            }
            guard !Task.isCancelled else { return }
            loadedViewModel = container.makePainRecordViewModel(patientId: patient.user.id)
            startRecordIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            connectionState = authRepository.isSignedIn() ? .failed : .signedOut
        }
    }

    private func recordContent(viewModel: PainRecordViewModel) -> some View {
        Group {
            if let completion = state.completion {
                PainCompletionView(
                    record: completion,
                    isSaving: viewModel.isSaving,
                    onRecordAgain: recordAgain,
                    onShowRecord: onShowRecord.map { destination in
                        { saveAndMove(to: destination) }
                    },
                    onHome: onHome.map { destination in
                        { saveAndMove(to: destination) }
                    }
                )
            } else {
                switch step {
                case 0:
                    PainLocationSelectionView(locations: viewModel.selectedLocations, errorMessage: state.errorMessage,
                        onToggle: { location in viewModel.selectLocation(location) },
                        onRemove: { location in viewModel.removeLocation(location) },
                        onNext: { step = 1 }, onClose: close)
                case 1:
                    PainBeforeMedicationView(locations: viewModel.selectedLocations, score: beforeScoreBinding,
                        onPrevious: { step = 0 }, onNext: {
                            guard viewModel.painBefore != nil else { return }
                            step = 2
                        }, onClose: close)
                default:
                    PainAfterMedicationView(locations: viewModel.selectedLocations, before: viewModel.painBefore,
                        score: afterScoreBinding, isSaving: viewModel.isSaving,
                        errorMessage: state.errorMessage,
                        onPrevious: { step = 1 }, onNext: prepareSummary, onClose: close)
                }
            }
        }
    }

    private var beforeScoreBinding: Binding<Int?> {
        Binding(
            get: { activeViewModel?.painBefore },
            set: { score in
                if let score { activeViewModel?.setBeforeScore(score) }
            }
        )
    }

    private var afterScoreBinding: Binding<Int?> {
        Binding(
            get: { activeViewModel?.painAfter },
            set: { score in
                if let score { activeViewModel?.setAfterScore(score) }
            }
        )
    }

    private func prepareSummary() {
        guard let viewModel = activeViewModel else { return }
        do {
            let record = try viewModel.prepareRecord()
            state.completion = PainCompletionData(
                location: record.location,
                painBefore: record.painBefore,
                painAfter: record.painAfter,
                painChange: record.painChange
            )
            state.errorMessage = nil
        } catch {
            state.errorMessage = "통증 기록을 준비하지 못했어요."
        }
    }

    private func startRecordIfNeeded() {
        guard let viewModel = activeViewModel, !didStartRecord else { return }

        do {
            try viewModel.startRecord()
            didStartRecord = true
            state.errorMessage = nil
        } catch {
            state.errorMessage = "통증 기록을 시작하지 못했어요."
        }
    }

    private func recordAgain() {
        guard let viewModel = activeViewModel else { return }
        do {
            try viewModel.startRecord()
            state.completion = nil
            state.errorMessage = nil
            step = 0
        } catch {
            activeAlert = .recordAgainFailed
        }
    }

    private func saveAndMove(to destination: @escaping () -> Void) {
        guard let viewModel = activeViewModel, !viewModel.isSaving else { return }

        Task { @MainActor in
            do {
                _ = try await viewModel.savePreparedRecord()
                destination()
            } catch PainRecordViewModel.SaveError.alreadySaving {
                return
            } catch {
                activeAlert = .saveFailed
            }
        }
    }

    private func close() { if let onClose { onClose() } else { dismiss() } }
}
#if DEBUG
private struct PreviewPainRepository: PainRepository {
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
    func save(entity: PainRecord) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { [] }
    func findByPatientIdAndDate(
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PainRecord] { [] }
}

extension PainRecordView {
    @MainActor
    static func preview(state: PainScreenState = PainScreenState()) -> Self {
        Self(
            viewModel: PainRecordViewModel(patientId: UUID(), painRepository: PreviewPainRepository()),
            state: state
        )
    }
}

#Preview("입력 화면 · 저장 미연결") { PainRecordView.preview() }
#Preview("완료 화면 · 예시 결과") {
    let state = PainScreenState()
    state.completion = .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             painBefore: 7, painAfter: 0, painChange: 7)
    return PainRecordView.preview(state: state)
}
#endif
