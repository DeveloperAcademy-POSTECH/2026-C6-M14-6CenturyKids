import SwiftUI

struct OnboardingHistoryView: View {
    var body: some View {
        OnboardingPageContent(
            title: "의사 선생님과 함께해요",
            description: "수집된 기록은 더 나은 진료를 위해\n의사 선생님께 전달 돼요"
        ) {
            OnboardingFeatureIllustration.doctorReview
        }
    }
}

#Preview { OnboardingHistoryView().background(AppColors.Semantic.Background.surface) }
