import SwiftUI

/// View는 입력과 페이지 이동을 담당하고 저장 요청을 외부로 전달합니다.
struct PainRecordView: View {
    @State private var state: PainScreenState
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss
    var onSave: ((PainFormInput) -> Void)?
    var onClose: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

    init(state: PainScreenState = PainScreenState(), onSave: ((PainFormInput) -> Void)? = nil,
         onClose: (() -> Void)? = nil, onShowRecord: (() -> Void)? = nil,
         onHome: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        _state = State(initialValue: state)
        self.onSave = onSave; self.onClose = onClose; self.onShowRecord = onShowRecord
        self.onHome = onHome; self.onCancel = onCancel
    }
    var body: some View {
        @Bindable var state = state
        Group {
            if let completion = state.completion {
                PainCompletionView(record: completion, onRecordAgain: {
                    state.input = PainFormInput()
                    state.errorMessage = nil
                    state.completion = nil
                    step = 0
                }, onShowRecord: onShowRecord, onHome: onHome)
            } else {
                switch step {
                case 0:
                    PainLocationSelectionView(locations: state.input.locations, errorMessage: state.errorMessage,
                        onToggle: { location in
                            if state.input.locations.contains(location) { state.input.locations.removeAll { $0 == location } }
                            else { state.input.locations.append(location) }
                        }, onRemove: { location in state.input.locations.removeAll { $0 == location } },
                        onNext: { step = 1 }, onClose: close)
                case 1:
                    PainBeforeMedicationView(locations: state.input.locations, score: $state.input.before,
                        onPrevious: { step = 0 }, onNext: { step = 2 }, onClose: close)
                default:
                    PainAfterMedicationView(locations: state.input.locations, before: state.input.before ?? 0,
                        score: $state.input.after, isSaving: state.isSaving,
                        errorMessage: state.errorMessage ?? (onSave == nil ? "저장 기능 연결 전이에요. 입력한 값은 저장되지 않아요." : nil),
                        onPrevious: { step = 1 }, onSave: onSave.map { save in { save(state.input) } }, onClose: close)
                }
            }
        }.onDisappear { onCancel?() }
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
}
#Preview("입력 화면 · 저장 미연결") { PainRecordView() }
#Preview("완료 화면 · 예시 결과") {
    let state = PainScreenState()
    state.completion = .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             painBefore: 7, painAfter: 0, painChange: 7)
    return PainRecordView(state: state)
}
