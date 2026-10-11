import SwiftUI

struct SignupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("회원가입")
                .font(.title2.bold())

            Text("환자 계정과 기본 정보를 등록하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    SignupView()
}
