import SwiftUI

/// 제품 진입점입니다. 인증과 DB 환자 정보가 함께 확인된 경우에만 기존 환자 화면을 엽니다.
@MainActor struct ContentView: View {
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
            // 화면 수명을 유지한 채 진행 표시만 겹칩니다. 복구 중 View의 onDisappear가 호출되지 않습니다.
            if authFlow.showsProgress {
                ProgressView("로그인 정보를 확인하고 있어요")
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        // 후속 기능 VM은 확인된 환자의 session.patient.user.id를 사용하면 됩니다.
        .environment(authFlow.session)
        .task { await authFlow.restoreSessionOnce() }
        .onOpenURL { url in Task { await authFlow.handleURL(url) } }
        .alert("인증 링크 안내", isPresented: Binding(get: { flow.linkMessage != nil }, set: { if !$0 { flow.linkMessage = nil } })) {
            Button("확인") { flow.linkMessage = nil }
        } message: { Text(flow.linkMessage ?? "") }
    }
}

#Preview { ContentView(authFlow: AuthFlowViewModel()) }
