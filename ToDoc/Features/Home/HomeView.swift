import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("홈")
                .font(.title2.bold())

            Text("오늘의 기록을 시작하고 주치의 메시지를 확인하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    HomeView()
}
