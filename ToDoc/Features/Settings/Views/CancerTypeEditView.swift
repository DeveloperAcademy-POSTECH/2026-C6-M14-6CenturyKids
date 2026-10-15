import SwiftUI
struct CancerTypeEditView: View {
    var state: DiagnosisScreenState?
    var onSaved: () -> Void = {}
    var body: some View { DiagnosisEditScreen(state: state, field: .carcinoma, onSaved: onSaved) }
}
#Preview { NavigationStack { CancerTypeEditView() } }
