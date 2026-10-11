import SwiftUI

struct NotificationView: View {
    var body: some View {
        AppHeader(
            title: "알림",
            description: "의료진 메시지와 기록 알림을 확인하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    NotificationView()
}
