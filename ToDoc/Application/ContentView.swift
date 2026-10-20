import SwiftUI

@MainActor
struct ContentView: View {
    @State private var painViewModel: PainRecordViewModel

    init(container: DependencyContainer) {
        _painViewModel = State(initialValue: container.makePainRecordViewModel())
    }

    var body: some View {
        PatientFlowView(pain: { PainRecordView(viewModel: painViewModel) })
    }
}

#if DEBUG
#Preview { PatientFlowView(pain: { .preview() }) }
#endif
