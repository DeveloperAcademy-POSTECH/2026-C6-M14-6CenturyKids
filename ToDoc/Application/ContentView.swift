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
                }
        }
        .task {
            container.liveActivityService.startObserving()
            container.localNotifications.onOpen = { type in
                guard type == .previsitReminder else { return }
                router.handle(.previsit)
            }
            // 로그인이 풀린 채 앱을 열면 지난 환자의 병원 감시를 멈춘다 (로그아웃은 아래 onChange가 멈춘다)
            await authFlow.restoreSessionOnce()
            if authFlow.session.patient == nil {
                container.hospitalArrivalService.stop()
            }
        }
        .onChange(of: authFlow.session.patient?.user.id) { _, patientId in
            guard patientId == nil else { return }
            container.locationPermission.onChange = nil
            container.hospitalArrivalService.onSaved = nil
            container.hospitalArrivalService.stop()
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
