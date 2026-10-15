import SwiftUI

struct OnboardingRecordTypesView: View {
    var body: some View {
        OnboardingPageContent(title: "통증과 증상을,\n편하게 기록해요",
                              description: "약 복용 전후의 통증과\n오늘의 증상을 남겨보세요.") {
            Image("HakroDoctor").resizable().scaledToFit().frame(maxWidth: 260).accessibilityHidden(true)
        }
    }
}
#Preview { OnboardingRecordTypesView().appScreenStyle() }
