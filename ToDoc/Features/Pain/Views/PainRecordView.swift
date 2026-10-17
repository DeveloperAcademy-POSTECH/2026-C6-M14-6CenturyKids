import SwiftUI

/// View는 입력과 페이지 이동을 담당하고 저장 요청을 외부로 전달합니다.
struct PainRecordView: View {
    let viewModel: PainRecordViewModel
    @State private var state: PainScreenState
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss
    var onSave: ((PainFormInput) -> Void)?
    var onClose: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

    init(viewModel: PainRecordViewModel, state: PainScreenState = PainScreenState(), onSave: ((PainFormInput) -> Void)? = nil,
         onClose: (() -> Void)? = nil, onShowRecord: (() -> Void)? = nil,
         onHome: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.viewModel = viewModel
        _state = State(initialValue: state)
        self.onSave = onSave; self.onClose = onClose; self.onShowRecord = onShowRecord
        self.onHome = onHome; self.onCancel = onCancel
    }
    var body: some View {
        @Bindable var state = state
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
                    PainBeforeMedicationView(locations: viewModel.selectedLocations, score: $state.input.before,
                        onPrevious: { step = 0 }, onNext: { step = 2 }, onClose: close)
                default:
                    PainAfterMedicationView(locations: viewModel.selectedLocations, before: state.input.before ?? 0,
                        score: $state.input.after, isSaving: state.isSaving,
                        errorMessage: state.errorMessage ?? (onSave == nil ? "저장 기능 연결 전이에요. 입력한 값은 저장되지 않아요." : nil),
                        onPrevious: { step = 1 }, onSave: onSave.map { save in { save(state.input) } }, onClose: close)
                }
            }
        }.onDisappear { onCancel?() }
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
