import SwiftUI

struct SettingsView: View {
    var body: some View {
        AppHeader(
            title: "설정",
            description: "개인 정보와 건강 정보, 의료진 연결을 관리하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    SettingsView()
}
