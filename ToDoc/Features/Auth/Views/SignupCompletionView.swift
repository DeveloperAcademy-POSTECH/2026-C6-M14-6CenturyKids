import SwiftUI

struct SignupCompletionView: View {
    let email: String
    let onLogin: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 40) {
                    AppFeedback.StatusIcon(kind: .success, size: 160)
                    VStack(spacing: 12) {
                        Text("가입을 완료했어요!").appTypography(.title)
                            .foregroundStyle(AppColors.Text.primary)
                            .accessibilityAddTraits(.isHeader)
                        Text("로그인 후 기록을 시작해 보세요")
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Text.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.top, max(40, 302 - geometry.safeAreaInsets.top))
                .padding(.bottom, 24)
                .accessibilityElement(children: .combine)
                .accessibilityValue(email)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppActions.Button("로그인 하러가기", action: onLogin)
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.top, 16)
                .background(AppColors.Semantic.Background.surface)
        }
        .background(AppColors.Semantic.Background.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { SignupCompletionView(email: "preview@example.com", onLogin: {}) }
