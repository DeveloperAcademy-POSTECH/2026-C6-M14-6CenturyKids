import SwiftUI

@MainActor
struct ContentView: View {
    @State private var authFlow: AuthFlowViewModel
    @State private var router = AppRouter()
    
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _authFlow = State(initialValue: container.makeAuthFlow())
    }

    var body: some View {
        AuthRootView(authFlow: authFlow) { patient in
            PatientFlowCompositionView(container: container, patientId: patient.user.id)
        }
        .environment(router)
        .onOpenURL { url in
            if let deepLink = DeepLink(url: url) {
                router.handle(deepLink)
            } else {
                Task {
                    await authFlow.handleURL(url)
                }
            }
        }
    }
}

#if DEBUG
#Preview { PatientFlowView(pain: { .preview() })
        .environment(AppRouter())
}
#endif
