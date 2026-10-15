import SwiftUI

struct OnboardingHistoryView: View {
    var body: some View {
        OnboardingPageContent(
            title: "차곡차곡 쌓인 기록,\n진료에 활용돼요",
            description: "날짜별 변화와 지난 기록을 모아\n진료 때 나눌 이야기를 준비해요."
        ) {
            OnboardingExampleImage(
                name: "OnboardingHistoryExample",
                label: "통증의 흐름. 최근 7일의 변화를 보여주는 예시 그래프예요."
            )
        }
    }
}

#Preview { OnboardingHistoryView().appScreenStyle() }
