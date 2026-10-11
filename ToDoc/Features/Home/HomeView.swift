import SwiftUI

struct HomeView: View {
    var body: some View {
        AppHeader(
            title: "홈",
            description: "오늘의 기록을 시작하고 주치의 메시지를 확인하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    HomeView()
}
