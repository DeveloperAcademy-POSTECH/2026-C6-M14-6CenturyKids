import SwiftUI

struct OnboardingConversationView: View {
    var body: some View {
        OnboardingPageContent(
            title: "통증을 간편하게 남겨요",
            description: "어디가 얼마나 아픈지 알려주세요"
        ) {
            OnboardingFeatureIllustration.pain
        }
    }
}

#Preview { OnboardingConversationView().background(AppColors.Semantic.Background.surface) }
