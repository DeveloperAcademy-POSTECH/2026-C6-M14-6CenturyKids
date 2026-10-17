import SwiftUI

/// View는 입력과 페이지 이동을 담당하고, ViewModel에서 기록을 준비합니다.
struct PainRecordView: View {
    let viewModel: PainRecordViewModel
    @State private var state: PainScreenState
    @State private var step = 0
    @State private var didStartRecord = false
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

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
            if let completion = state.completion {
                PainCompletionView(record: completion, onShowRecord: onShowRecord, onHome: onHome)
            } else {
                switch step {
                case 0:
                    PainLocationSelectionView(locations: viewModel.selectedLocations, errorMessage: state.errorMessage,
                        onToggle: { location in viewModel.selectLocation(location) },
                        onRemove: { location in viewModel.removeLocation(location) },
                        onNext: { step = 1 }, onClose: close)
                case 1:
                    PainBeforeMedicationView(locations: viewModel.selectedLocations, score: beforeScoreBinding,
                        onPrevious: { step = 0 }, onNext: { step = 2 }, onClose: close)
                default:
                    PainAfterMedicationView(locations: viewModel.selectedLocations, before: viewModel.painBefore,
                        score: afterScoreBinding, isSaving: state.isSaving,
                        errorMessage: state.errorMessage,
                        onPrevious: { step = 1 }, onNext: prepareSummary, onClose: close)
                }
            }
        }
        .onAppear { startRecordIfNeeded() }
        .onDisappear { onCancel?() }
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

    private func prepareSummary() {
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
        guard !didStartRecord else { return }

        do {
            try viewModel.startRecord()
            didStartRecord = true
            state.errorMessage = nil
        } catch {
            state.errorMessage = "통증 기록을 시작하지 못했어요."
        }
    }

    private func close() { if let onClose { onClose() } else { dismiss() } }
}
#if DEBUG
private struct PreviewPainRepository: PainRepository {
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
    func save(_ entity: PainRecord, for patientId: UUID) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { [] }
    func findByPatientIdAndDate(_ patientId: UUID, _ date: Date) async throws -> [PainRecord] { [] }
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
