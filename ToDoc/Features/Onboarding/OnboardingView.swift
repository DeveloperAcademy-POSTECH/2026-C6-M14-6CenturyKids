import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("온보딩")
                .font(.title2.bold())

            Text("통증과 증상, 식사와 운동 기록 기능을 소개하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    OnboardingView()
}
