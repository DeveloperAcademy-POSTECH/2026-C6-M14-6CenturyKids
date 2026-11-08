import SwiftUI
import KakaoSDKAuth

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var authFlow: AuthFlowViewModel
    @State private var router: AppRouter
    @State private var showsSplash = true

    private let container: DependencyContainer

    init(container: DependencyContainer, router: AppRouter) {
        self.container = container
        _authFlow = State(initialValue: container.makeAuthFlow())
        _router = State(initialValue: router)
    }

    var body: some View {
        AuthRootView(authFlow: authFlow) { patient in
            PatientFlowCompositionView(container: container, patientId: patient.user.id)
                                          .task(id: patient.user.id) {
                    await syncLiveActivityToken()
                    await LocalNotificationAdapter.schedulePainReminders()
                }
        }
        // 기존 화면을 유지한 채 가려 세션 복원과 딥 링크 처리를 함께 진행합니다.
        .allowsHitTesting(!showsSplash)
        .accessibilityHidden(showsSplash)
        .overlay {
            if showsSplash {
                SplashVideoView { showsSplash = false }
                    .ignoresSafeArea()
            }
        }
        .statusBarHidden(showsSplash)
        .task {
            container.liveActivityService.startObserving()
            // 앱을 끈 사이에 로그인이 끝났으면 복원 뒤에도 환자가 없으니 남은 예약과 병원 감시를 멈춘다.
            await authFlow.restoreSessionOnce()
            if authFlow.session.patient == nil {
                LocalNotificationAdapter.cancelPainReminders()
                container.hospitalArrivalService.stop()
            }
        }
        // 로그아웃은 모두 session.patient를 비우는 것으로 끝난다.
        .onChange(of: authFlow.session.patient?.user.id) { oldID, newID in
            guard oldID != nil, newID == nil else { return }
            LocalNotificationAdapter.cancelPainReminders()
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
            if AuthApi.isKakaoTalkLoginUrl(url) {
                _ = AuthController.handleOpenUrl(url: url)
            } else if let deepLink = DeepLink(url: url) {
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
