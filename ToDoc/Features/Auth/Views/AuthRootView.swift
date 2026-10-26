import SwiftUI

/// 인증 화면을 기본으로 표시하고, 확인된 환자가 있을 때만 환자 화면으로 전환합니다.
@MainActor struct AuthRootView<PatientContent: View>: View {
    @State var authFlow: AuthFlowViewModel
    let patientContent: (Patient) -> PatientContent

    var body: some View {
        @Bindable var flow = authFlow
        ZStack {
            Group {
                switch authFlow.rootRoute {
                case .patient:
                    if let patient = authFlow.session.patient {
                        patientContent(patient).id(patient.user.id)
                    }
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
        // 자동 로그인 여부와 저장된 환자 정보의 유효성은 인증 ViewModel이 확인합니다.
        .task { await authFlow.restoreSessionOnce() }
        .alert("인증 링크 안내", isPresented: Binding(get: { flow.linkMessage != nil }, set: { if !$0 { flow.linkMessage = nil } })) {
            Button("확인") { flow.linkMessage = nil }
        } message: { Text(flow.linkMessage ?? "") }
    }
}

// Canvas는 실제 서버 대신 기본 미연결 VM을 사용합니다. 앱 실행의 실제 DI와 구분합니다.
#if DEBUG
#Preview {
    AuthRootView(authFlow: AuthFlowViewModel()) { _ in
        PatientFlowView.preview()
    }
    .environment(AppRouter())
}
#endif
