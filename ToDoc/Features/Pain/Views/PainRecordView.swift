import SwiftUI

/// View는 입력과 페이지 이동을 담당하고, ViewModel에서 기록을 저장합니다.
/// 먹기 전 통증을 먼저 저장하고, 1시간 뒤 같은 기록에 먹은 뒤 통증을 이어서 기록합니다.
struct PainRecordView: View {
    let viewModel: PainRecordViewModel
    @State private var state: PainScreenState
    @State private var stage = Stage.start
    @State private var savedRecord: PainRecord?
    @State private var showsSaveFailed = false
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)?
    var onShowRecord: ((PainRecord) -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

    private enum Stage {
        /// 기다리는 기록이 있으면 대기 화면이나 분기 화면, 없으면 부위 선택
        case start
        case location
        case before
        case beforeSaved
        case after
    }

    init(viewModel: PainRecordViewModel, state: PainScreenState = PainScreenState(),
         onClose: (() -> Void)? = nil, onShowRecord: ((PainRecord) -> Void)? = nil,
         onHome: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.viewModel = viewModel
        _state = State(initialValue: state)
        self.onClose = onClose; self.onShowRecord = onShowRecord
        self.onHome = onHome; self.onCancel = onCancel
    }
    var body: some View {
        Group {
            switch viewModel.connectionState {
            case .ready:
                recordContent
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
                        Task { await load() }
                    }
                }
            }
        }
        .task { await load() }
        .onDisappear { onCancel?() }
        .alert("기록을 저장하지 못했어요", isPresented: $showsSaveFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
    }

    private func load() async {
        await viewModel.load()
        guard !Task.isCancelled, case .ready = viewModel.connectionState else { return }
        stage = viewModel.pendingRecord == nil ? .location : .start
    }

    @ViewBuilder private var recordContent: some View {
        if let completion = state.completion {
            PainCompletionView(
                record: completion,
                onRecordAgain: beginNewRecord,
                onShowRecord: onShowRecord.map { destination in
                    { if let savedRecord { destination(savedRecord) } }
                },
                onHome: home
            )
        } else {
            switch stage {
            case .start:
                if let pending = viewModel.pendingRecord, let availableDate = viewModel.afterAvailableDate {
                    // 대기 화면은 남은 시간을 스스로 세므로, 여기서는 기록할 수 있게 되는 순간에 한 번만 바꿉니다.
                    TimelineView(.explicit([.now, availableDate])) { context in
                        if context.date < availableDate {
                            PainAfterWaitingView(locations: pending.location, before: pending.painBefore,
                                                 availableDate: availableDate,
                                                 onNewRecord: beginNewRecord, onClose: close)
                        } else {
                            PainRecordChoiceView(locations: pending.location, before: pending.painBefore,
                                                 recordedDate: pending.recordedDate,
                                                 onContinue: { stage = .after },
                                                 onNewRecord: beginNewRecord, onClose: close)
                        }
                    }
                } else {
                    locationSelection
                }
            case .location:
                locationSelection
            case .before:
                PainBeforeMedicationView(locations: viewModel.selectedLocations, score: beforeScoreBinding,
                    isSaving: viewModel.isSaving, errorMessage: state.errorMessage,
                    onPrevious: { stage = .location }, onReselectLocations: { stage = .location },
                    onNext: saveBefore, onClose: close)
            case .beforeSaved:
                PainBeforeSavedView(before: viewModel.pendingRecord?.painBefore ?? 0, onHome: home)
            case .after:
                if let pending = viewModel.pendingRecord {
                    PainAfterMedicationView(locations: pending.location, before: pending.painBefore,
                        score: afterScoreBinding, isSaving: viewModel.isSaving,
                        errorMessage: state.errorMessage,
                        onPrevious: { stage = .start }, onNext: saveAfter, onClose: close)
                }
            }
        }
    }

    private var locationSelection: some View {
        PainLocationSelectionView(locations: viewModel.selectedLocations, errorMessage: state.errorMessage,
            onToggle: viewModel.toggleLocation, onRemove: viewModel.removeLocation,
            onRemoveAll: viewModel.removeAllLocations,
            onNext: { stage = .before }, onClose: close)
    }

    private var beforeScoreBinding: Binding<Int?> {
        Binding(
            get: { viewModel.painBefore },
            set: { score in
                if let score { viewModel.setBeforeScore(score) }
            }
        )
    }

    private var afterScoreBinding: Binding<Int?> {
        Binding(
            get: { viewModel.painAfter },
            set: { score in
                if let score { viewModel.setAfterScore(score) }
            }
        )
    }

    /// 새로 기록하면 기다리던 기록은 먹기 전 점수만 남습니다. 새 기록을 저장할 때 알림도 새 기록으로 바뀝니다.
    private func beginNewRecord() {
        viewModel.startNewRecord()
        savedRecord = nil
        state.completion = nil
        state.errorMessage = nil
        stage = .location
    }

    private func saveBefore() {
        guard !viewModel.isSaving else { return }

        Task { @MainActor in
            do {
                _ = try await viewModel.saveBeforeRecord()
                state.errorMessage = nil
                stage = .beforeSaved
            } catch PainRecordViewModel.SaveError.alreadySaving {
                return
            } catch {
                showsSaveFailed = true
            }
        }
    }

    private func saveAfter() {
        guard !viewModel.isSaving else { return }

        Task { @MainActor in
            do {
                let record = try await viewModel.saveAfterRecord()
                savedRecord = record
                state.errorMessage = nil
                state.completion = PainCompletionData(
                    location: record.location,
                    painBefore: record.painBefore,
                    painAfter: record.painAfter,
                    painChange: record.painChange
                )
            } catch PainRecordViewModel.SaveError.alreadySaving {
                return
            } catch {
                showsSaveFailed = true
            }
        }
    }

    private func home() { if let onHome { onHome() } else { dismiss() } }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}
#if DEBUG
private struct PreviewPainRepository: PainRepository {
    var latest: PainRecord?
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
    func save(entity: PainRecord) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { [] }
    func findByPatientIdAndDate(
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PainRecord] { [] }
    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord? { latest }
    func savePainAfter(recordId: UUID, painAfter: Int) async throws {}
}

extension PainRecordView {
    @MainActor
    static func preview(state: PainScreenState = PainScreenState(), beforeSavedAgo: TimeInterval? = nil) -> Self {
        let patientId = UUID()
        let latest = beforeSavedAgo.flatMap {
            try? PainRecord(id: UUID(), patientId: patientId, recordedDate: .now.addingTimeInterval(-$0),
                            location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                            painBefore: 7, painAfter: nil)
        }
        return Self(
            viewModel: PainRecordViewModel(patientId: patientId, painRepository: PreviewPainRepository(latest: latest)),
            state: state
        )
    }
}

#Preview("입력 화면 · 저장 미연결") { PainRecordView.preview() }
#Preview("1시간 전 · 대기") { PainRecordView.preview(beforeSavedAgo: 20 * 60) }
#Preview("1시간 뒤 · 이어가기 선택") { PainRecordView.preview(beforeSavedAgo: 90 * 60) }
#Preview("완료 화면 · 예시 결과") {
    let state = PainScreenState()
    state.completion = .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             painBefore: 7, painAfter: 0, painChange: 7)
    return PainRecordView.preview(state: state)
}
#endif
