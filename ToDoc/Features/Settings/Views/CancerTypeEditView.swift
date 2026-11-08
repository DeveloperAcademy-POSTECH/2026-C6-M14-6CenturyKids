import SwiftUI

struct CancerTypeEditView: View {
    var state: DiagnosisScreenState?
    var onSaved: () -> Void = {}
    var customCancerName: Binding<String>?
    var onBeginCustomCancer: (() -> Void)?
    var onSubmitCustomCancer: ((String) -> Void)?
    var onCancelCustomCancer: (() -> Void)?
    @State private var showsEntry = false
    @State private var draftName = ""

    var body: some View {
        DiagnosisEditScreen(state: state, field: .carcinoma, onSaved: onSaved, onAddCancer: {
            if case .carcinoma(let type)? = state?.selection,
               !CarcinomaType.allCases.contains(type) {
                draftName = type.displayName
            } else { draftName = "" }
            onBeginCustomCancer?()
            showsEntry = true
        })
        .sheet(isPresented: $showsEntry, onDismiss: { onCancelCustomCancer?() }) {
            CancerTypeEntryView(name: customCancerName ?? $draftName,
                                isSaving: state?.isSaving == true,
                                errorMessage: state?.errorMessage,
                                onSubmit: onSubmitCustomCancer)
                .presentationDetents([.large])
        }
    }
}
#Preview("암종 선택 · 저장 미연결") {
    NavigationStack {
        CancerTypeEditView(state: {
            let state = DiagnosisScreenState()
            state.selection = .carcinoma(.lung)
            state.canSave = true
            return state
        }())
    }
}
