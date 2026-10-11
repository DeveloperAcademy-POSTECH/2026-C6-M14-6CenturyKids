import SwiftUI

struct IntakeRecordView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("식사 기록")
                .font(.title2.bold())

            Text("끼니별 식사량과 선택적인 사진을 기록하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    IntakeRecordView()
}
