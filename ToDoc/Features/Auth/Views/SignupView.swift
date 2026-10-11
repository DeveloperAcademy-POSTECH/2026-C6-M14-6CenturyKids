import SwiftUI

struct SignupView: View {
    var body: some View {
        AppHeader(
            title: "회원가입",
            description: "환자 계정과 기본 정보를 등록하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    SignupView()
}
