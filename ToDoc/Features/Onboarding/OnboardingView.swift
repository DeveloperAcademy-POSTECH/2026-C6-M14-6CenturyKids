import SwiftUI

struct OnboardingView: View {
    var body: some View {
        AppHeader(
            title: "온보딩",
            description: "통증과 증상, 식사와 운동 기록 기능을 소개하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    OnboardingView()
}
