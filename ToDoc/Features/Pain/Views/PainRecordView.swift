import SwiftUI

struct PainRecordView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("통증 기록")
                .font(.title2.bold())

            Text("약 복용 전후의 통증 변화를 기록하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    PainRecordView()
}
