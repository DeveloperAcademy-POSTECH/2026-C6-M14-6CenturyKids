import SwiftUI

struct OnboardingRecordTypesView: View {
    var body: some View {
        OnboardingPageContent(
            title: "통증부터 식사까지,\n필요한 것만 기록해요",
            description: "약 복용 전후 통증과 식사량,\n운동 미션을 간단하게 남겨보세요."
        ) {
            OnboardingExampleImage(
                name: "OnboardingRecordExample",
                label: "기록 예시. 통증·약, 식사, 운동을 기록할 수 있어요. 복용 전 통증 7점, 복용 후 4점."
            )
        }
    }
}

#Preview { OnboardingRecordTypesView().appScreenStyle() }
