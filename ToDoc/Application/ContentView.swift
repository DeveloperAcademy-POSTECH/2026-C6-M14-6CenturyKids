import SwiftUI

@MainActor
struct ContentView: View {
    @State private var painViewModel: PainRecordViewModel
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _painViewModel = State(initialValue: container.makePainRecordViewModel())
    }

    var body: some View {
        PatientFlowCompositionView(container: container)
        PatientFlowView(
            pain: { PainRecordView(viewModel: painViewModel) },
            // 케어콜 ViewModel은 화면에 들어갈 때마다 새로 만든다 (나가면 AI 모델이 풀린다)
            careCall: { CareCallFlowView(makeViewModel: container.makeCareCallViewModel) }
        )
    }
}

#if DEBUG
#Preview { PatientFlowView(pain: { .preview() }) }
#endif
