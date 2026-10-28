import SwiftUI

/// Figma 316:7102 포괄 오류화면. 케어콜을 시작하지 못했거나 대화가 끊겨 보여 줄 질문이 없을 때 씁니다.
struct SymptomServiceErrorView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 40) {
                        AppFeedback.StatusIcon(kind: .error, size: 160)
                        VStack(spacing: 16) {
                            Text("서비스 이용이 원활하지 않아요")
                                .modifier(SymptomTextStyle(size: 16, weight: .semibold)).foregroundStyle(.black)
                                .accessibilityAddTraits(.isHeader)
                            Text("불편을 드려 죄송합니다.\n잠시 후에 다시 시도해 주세요.")
                                .modifier(SymptomTextStyle(size: 14, weight: .medium))
                                .foregroundStyle(Color(white: 114 / 255))
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    // Figma: 화면 가운데보다 조금 위
                    .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 80))
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            Button { onRetry?() } label: {
                AppForwardLabel(title: "다시 시도하기", asset: "CareConversationNext")
            }
            .buttonStyle(AppButtonStyle())
            .disabled(onRetry == nil)
            .accessibilityIdentifier("symptom.retry")
            .padding(.horizontal, 24).padding(.bottom, 2)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { SymptomServiceErrorView(onRetry: {}) }
