import SwiftUI

struct PainScoreInputView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    var before: Int?
    var isSaving = false
    var errorMessage: String?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?
    var descriptor: (Int) -> String? = painScoreDescription

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // 큰 글자에서는 안내/버튼이 게이지를 가리지 않도록 전체를 스크롤합니다.
                ScrollView { VStack(spacing: AppSpacing.section) { inputContent; footer } }
            } else {
                VStack(spacing: 0) {
                    ScrollView { inputContent }
                    footer
                }
            }
        }
        .background(AppColors.surface)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var inputContent: some View {
        VStack(spacing: 0) {
            AppHeader(title: "통증 변화 기록", description: before == nil
                      ? "약을 복용하기 전 통증 강도는 어떠셨나요?"
                      : "약을 복용한 후 통증 강도는 어떠셨나요?")
            PainLocationChips(locations: locations).padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, AppSpacing.section)
            PainScoreGauge(value: $score, before: before,
                           label: before == nil ? "약 복용 전 통증 점수" : "약 복용 후 통증 점수",
                           descriptor: descriptor)
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 25).disabled(isSaving)
        }
        .padding(.bottom, AppSpacing.item)
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.section) {
            if let errorMessage { Text(errorMessage).font(AppTypography.NativeConversation.body).foregroundStyle(AppColors.Feedback.error).padding(.horizontal, AppSpacing.screenHorizontal) }
            Text("막대를 위아래로 움직여 통증 정도를 조절하세요")
                .appTextStyle(.caption).foregroundStyle(AppColors.Text.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, AppSpacing.screenHorizontal)
            PainInputFooter(title: isSaving ? "저장 중" : "다음", isEnabled: !isSaving,
                            isPreviousEnabled: !isSaving, onPrevious: onPrevious,
                            onNext: onNext.map { next in {
                                // 초기 막대가 가리키는 0점도 유효한 입력입니다.
                                if score == nil { score = 0 }
                                next()
                            } })
        }
    }
}
