import SwiftUI

/// Figma 316:7259 포괄 오류화면. 케어콜을 시작하지 못했거나 대화가 끊겨 보여 줄 질문이 없을 때 씁니다.
struct SymptomServiceErrorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onRetry: (() -> Void)?
    var onHome: () -> Void

    private var usesLargeLayout: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: usesLargeLayout ? 24 : 40) {
                        AppFeedback.StatusIcon(kind: .error, size: usesLargeLayout ? 72 : 160)
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
            let actions = usesLargeLayout
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: AppLayout.Phone.columnSpacing))
            actions {
                homeButton
                    .accessibilityLabel("홈으로 가기")
                    .accessibilityIdentifier("symptom.home")
                Button { onRetry?() } label: {
                    AppForwardLabel(title: "다시 시도하기", asset: "CareConversationNext")
                }
                .buttonStyle(AppButtonStyle())
                .disabled(onRetry == nil)
                .accessibilityIdentifier("symptom.retry")
            }
            .padding(.horizontal, 24).padding(.bottom, 2)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var homeButton: some View {
        if usesLargeLayout {
            Button("홈으로 가기", action: onHome)
                .buttonStyle(AppButtonStyle(kind: .secondary))
        } else {
            AppActions.BackButton("홈", action: onHome)
        }
    }
}

#Preview { SymptomServiceErrorView(onRetry: {}, onHome: {}) }
