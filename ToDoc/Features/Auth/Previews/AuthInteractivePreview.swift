#if DEBUG
import SwiftUI

/// 제품 View/VM을 그대로 사용하고, 이 Canvas에만 메모리 저장소와 예시 약관을 주입합니다.
struct AuthInteractivePreview: View {
    @State private var flow = AuthInteractivePreviewData.makeFlow()
    @State private var previewID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.tight) {
                HStack {
                    Text("화면 체험 · 서버 저장 없음").appFont(.captionStrong)
                    Spacer()
                    Button("처음부터") {
                        flow.close()
                        flow = AuthInteractivePreviewData.makeFlow()
                        previewID = UUID()
                    }
                    .disabled(flow.session.isBusy)
                    .accessibilityIdentifier("auth.preview.restart")
                }
                HStack {
                    Text("예시 코드 PRE123 · 약관은 직접 동의해 주세요")
                        .appFont(.controlCaption)
                        .foregroundStyle(AppColors.Text.secondary)
                    Spacer(minLength: AppSpacing.compact)
                    Button("예시 입력") { AuthInteractivePreviewData.fillExample(flow) }
                        .disabled(flow.signup.state.isWorking || flow.signup.state.isAccountLocked)
                        .accessibilityIdentifier("auth.preview.fill")
                }
            }
            .appFont(.captionRegular)
            .padding(.horizontal, AppSpacing.content)
            .padding(.vertical, AppSpacing.compact)
            .background(AppColors.Surface.control)

            OnboardingView(model: flow)
                .id(previewID)
        }
        .preferredColorScheme(.light)
    }
}

#Preview("온보딩 → 가입 완료 · 서버 없는 체험") {
    AuthInteractivePreview()
}

/// 이번에 바뀐 진단 입력부터 바로 확인하는 서버 없는 체험입니다.
private struct SignupDiagnosisPreview: View {
    @State private var flow: AuthFlowViewModel
    init(step: SignupStep) {
        let flow = AuthInteractivePreviewData.makeFlow()
        flow.open(.signup)
        flow.signup.state.acceptedTerms = Set(SignupTerm.allCases.filter(\.isRequired))
        flow.signup.state.cancerType = .other
        flow.signup.state.otherCancer = "연부조직 육종"
        if step == .cancerType { flow.signup.state.cancerSearch = "연부조직 육종" }
        flow.signup.state.stage = .unknown
        flow.signup.state.doctorCode = ""
        flow.signup.state.step = step
        _flow = State(initialValue: flow)
    }
    var body: some View { NavigationStack { AuthFlowView(model: flow) } }
}

#Preview("암종 기타 · 자유 텍스트부터") { SignupDiagnosisPreview(step: .cancerType) }
#Preview("병기 · 모르겠어요") { SignupDiagnosisPreview(step: .cancerStage) }
#endif
