import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var authFlow: AuthFlowViewModel
    @State private var router = AppRouter()
    
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _authFlow = State(initialValue: container.makeAuthFlow())
    }

    var body: some View {
        AuthRootView(authFlow: authFlow) { patient in
            PatientFlowCompositionView(container: container,patientId: patient.user.id,authSession: authFlow.session)
                                          .task(id: patient.user.id) {
                    await syncLiveActivityToken()
                    await LocalNotificationAdapter.schedulePainReminders()
                }
        }
        .task {
            container.liveActivityService.startObserving()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            
            Task {
                await syncLiveActivityToken()
            }
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
    
    private func syncLiveActivityToken() async {
        do {
            try await container.liveActivityService.syncToken()
        } catch {
            print("Live Activity 토큰 동기화 실패: ", error)
        }
    }
}

#if DEBUG
#Preview {
    PatientFlowView.preview()
        .environment(AppRouter())
}
#endif
