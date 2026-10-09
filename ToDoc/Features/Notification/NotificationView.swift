import SwiftUI

struct NotificationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("알림")
                .font(.title2.bold())

            Text("의료진 메시지와 기록 알림을 확인하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    NotificationView()
}
