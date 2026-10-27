import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var authFlow: AuthFlowViewModel
    @State private var router: AppRouter

    private let container: DependencyContainer

    init(container: DependencyContainer, router: AppRouter) {
        self.container = container
        _authFlow = State(initialValue: container.makeAuthFlow())
        _router = State(initialValue: router)
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
            // 앱을 끈 사이에 로그인이 끝났으면 복원 뒤에도 환자가 없으니 남은 예약을 지운다.
            await authFlow.restoreSessionOnce()
            if authFlow.session.patient == nil {
                LocalNotificationAdapter.cancelPainReminders()
            }
        }
        // 로그아웃은 모두 session.patient를 비우는 것으로 끝난다.
        .onChange(of: authFlow.session.patient?.user.id) { oldID, newID in
            guard oldID != nil, newID == nil else { return }
            LocalNotificationAdapter.cancelPainReminders()
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
