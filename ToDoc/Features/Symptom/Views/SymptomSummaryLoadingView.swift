import SwiftUI

/// Figma 1:1816. 마지막 답변 처리 중에만 표시합니다.
struct SymptomSummaryLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false
    var onCancel: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 60) {
                    Image("CareSummaryLoading").resizable().frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
                        .accessibilityHidden(true)
                    VStack(spacing: AppSpacing.section) {
                        Text("말씀해 주신 내용을 바탕으로\n문진 기록을 정리하고 있어요.")
                            .appFont(.question)
                        Text("잠시만 기다려 주세요")
                            .appFont(.body)
                            .foregroundStyle(AppColors.Text.secondary)
                    }
                    .multilineTextAlignment(.center)
                    if let onCancel {
                        // 장시간 대기/취소는 디자인 대기 중인 기본 동작입니다.
                        Button("종료하기", action: onCancel).buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, max(24, geometry.size.height * 0.27))
                .padding(.bottom, AppSpacing.section)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.surface)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { rotating = true }
        }
    }
}

#Preview { SymptomSummaryLoadingView() }
