import SwiftUI

struct LoginView: View {
    var body: some View {
        AppHeader(
            title: "로그인",
            description: "기존 계정으로 환자 앱을 이용하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    LoginView()
}
