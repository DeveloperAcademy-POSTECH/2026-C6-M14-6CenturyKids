import SwiftUI

@MainActor
struct ContentView: View {
    @State private var authFlow: AuthFlowViewModel
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _authFlow = State(initialValue: container.makeAuthFlow())
    }

    var body: some View {
        AuthRootView(authFlow: authFlow) { patient in
            PatientFlowCompositionView(container: container, patientId: patient.user.id)
        }
    }
}

#if DEBUG
#Preview { PatientFlowView(pain: { .preview() }) }
#endif
