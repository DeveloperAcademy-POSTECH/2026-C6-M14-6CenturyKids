#if DEBUG
import SwiftUI

/// `--auth-flow`로 실행했을 때만 사용하는 인증 개발 진입점입니다.
/// 화면 캡처용 예시와 달리 DependencyContainer가 조립한 실제 Repository 연결 상태로 동작합니다.
/// 이전 ContentView의 인증 흐름을 옮겨 보존합니다. 준비되지 않은 저장소를 우회하지 않습니다.
@MainActor struct AuthDevelopmentRootView: View {
    @State var authFlow: AuthFlowViewModel

    var body: some View {
        @Bindable var flow = authFlow
        ZStack {
            Group {
                switch authFlow.rootRoute {
                case .patient: PatientFlowView()
                case .authentication: OnboardingView(model: authFlow)
                }
            }
            .disabled(authFlow.showsProgress)
            // 진행 중에도 같은 화면을 유지해야 onDisappear가 복구 요청을 취소하지 않습니다.
            if authFlow.showsProgress {
                ProgressView("로그인 정보를 확인하고 있어요")
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .environment(authFlow.session)
        // 자동 로그인과 메일 링크 처리는 인증 개발 경로에서만 실행합니다.
        // 기본 홈 실행은 저장된 인증 세션을 복원하거나 로그아웃하지 않습니다.
        .task { await authFlow.restoreSessionOnce() }
        .onOpenURL { url in Task { await authFlow.handleURL(url) } }
        .alert("인증 링크 안내", isPresented: Binding(get: { flow.linkMessage != nil }, set: { if !$0 { flow.linkMessage = nil } })) {
            Button("확인") { flow.linkMessage = nil }
        } message: { Text(flow.linkMessage ?? "") }
    }
}

// Canvas는 실제 서버 대신 기본 미연결 VM을 사용합니다. 앱 실행의 실제 DI와 구분합니다.
#Preview { AuthDevelopmentRootView(authFlow: AuthFlowViewModel()) }
#endif
