import SwiftUI

struct OnboardingRecordTypesView: View {
    var body: some View {
        OnboardingPageContent(
            title: "진료 받기 전 돌아보세요",
            description: "진료를 기다리는 동안 기록을 돌아보고\n기분이 어떤지 알려주세요"
        ) {
            OnboardingDoctorIllustration()
        }
    }
}

#Preview { OnboardingRecordTypesView().background(AppColors.Semantic.Background.surface) }
