import SwiftUI

struct OnboardingDailyCareView: View {
    var body: some View {
        OnboardingPageContent(
            title: "음성으로 몸 상태를 기록해요",
            description: "오늘 몸 상태는 어떠셨나요?\n의사 선생님과 대화하듯 편하게 말해 주세요"
        ) {
            OnboardingDoctorIllustration()
        }
    }
}

#Preview { OnboardingDailyCareView().background(AppColors.Semantic.Background.surface) }
