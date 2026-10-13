import SwiftUI
struct CancerStageEditView: View {
    var state: DiagnosisScreenState?
    var onSaved: () -> Void = {}
    var body: some View { DiagnosisEditScreen(state: state, field: .stage, onSaved: onSaved) }
}
#Preview { NavigationStack { CancerStageEditView() } }
