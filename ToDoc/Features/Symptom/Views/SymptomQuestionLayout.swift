import SwiftUI

/// Figma 1:1837 / 1:1732 / 수동 입력 3종의 같은 진행·질문·하단 배치.
struct SymptomQuestionLayout<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let question: SymptomConversationQuestion
    var nextTitle = "답변을 입력해 주세요"
    var canProceed = false
    var switchTitle = "음성 전환"
    var showsPrevious = false
    var showsNext = true
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitch: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppConversationLayout {
            VStack(spacing: AppSpacing.question) {
                AppProgressTrack(value: question.progress)
                VStack(spacing: AppSpacing.compact) {
                    if let guidance = question.guidance {
                        Text(guidance).appFont(.body)
                            .foregroundStyle(AppColors.Text.secondary)
                    }
                    Text(question.text)
                        .appFont(.question)
                        .tracking(-0.2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .accessibilityElement(children: .combine)
                content()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.question)
            .padding(.bottom, AppSpacing.section)
        } footer: {
            VStack(spacing: AppSpacing.section) {
                HStack {
                    AppCircleControl(title: "종료하기", asset: "CareConversationClose", action: onEnd)
                    Spacer()
                    AppCircleControl(title: switchTitle, asset: "CareConversationText", action: onSwitch)
                }
                if showsNext {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.item)) : AnyLayout(HStackLayout(spacing: AppSpacing.columnGap))
                    layout {
                        if showsPrevious {
                            Button("이전") { onPrevious?() }
                                .buttonStyle(AppButtonStyle(kind: typeSize.isAccessibilitySize ? .secondary : .back))
                                .disabled(onPrevious == nil)
                        }
                        Button { onNext?() } label: {
                            AppForwardLabel(title: nextTitle, asset: "CareConversationNext")
                        }
                        .buttonStyle(AppButtonStyle())
                        .disabled(!canProceed || onNext == nil)
                        .accessibilityIdentifier("symptom.next")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, 2)
            .padding(.top, AppSpacing.compact)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
        .toolbar(.hidden, for: .navigationBar)
    }
}
