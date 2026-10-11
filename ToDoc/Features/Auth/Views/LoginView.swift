import SwiftUI

struct LoginView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("로그인")
                .font(.title2.bold())

            Text("기존 계정으로 환자 앱을 이용하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    LoginView()
}
