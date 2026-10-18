import SwiftUI

/// Figma 1:1823. 저장 성공 이후 부모 흐름에서 표시합니다.
struct SymptomCompletionView: View {
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.question) {
                        Image("CareSummaryCompleteCircle")
                            .resizable().frame(width: 100, height: 100)
                            .overlay { Image("CareSummaryCompleteCheck") }
                            .accessibilityHidden(true)
                        VStack(spacing: AppSpacing.section) {
                            Text("말씀해 주신 내용을 바탕으로\n문진 기록을 정리했어요.")
                                .appFont(.question)
                            Text("잠시만 기다려 주세요")
                                .appFont(.body)
                                .foregroundStyle(AppColors.Text.secondary)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, max(24, (geometry.size.height - 180) * 0.35))
                    .padding(.bottom, AppSpacing.section)
                }
                VStack(spacing: AppSpacing.columnGap) {
                    Button { onShowRecord?() } label: {
                        AppForwardLabel(title: "기록 확인하기", asset: "CareConversationNext")
                    }
                    .buttonStyle(AppButtonStyle()).disabled(onShowRecord == nil)
                    Button("홈으로 가기") { onHome?() }
                        .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onHome == nil)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, 2)
            }
        }
        .background(AppColors.surface)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { SymptomCompletionView(onShowRecord: {}, onHome: {}) }
