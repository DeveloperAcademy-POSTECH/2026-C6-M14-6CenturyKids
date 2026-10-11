import SwiftUI

struct OnboardingDailyCareView: View {
    var body: some View {
        OnboardingPageContent(
            title: "병원 밖의 하루도,\n함께 기록해요",
            description: "통증·식사·운동을 차근차근 남겨요.\n다음 진료 때 꺼내 보기 쉬워져요."
        ) {
            VStack(spacing: AppSpacing.Header.titleToDescription) {
                Image("HakroDoctor")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .accessibilityHidden(true)
                HStack {
                    Image("OnboardingMicrophone")
                        .resizable().scaledToFit().frame(width: 24, height: 32)
                        .accessibilityHidden(true)
                    Text("오늘의 안부 남기기").appTextStyle(.heading)
                }
            }
        }
    }
}

#Preview { OnboardingDailyCareView().appScreenStyle() }
