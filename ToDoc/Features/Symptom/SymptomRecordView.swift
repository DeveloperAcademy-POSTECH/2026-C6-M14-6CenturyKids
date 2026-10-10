import SwiftUI

struct SymptomRecordView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("하루 안부 기록")
                .font(.title2.bold())

            Text("하루 동안 느낀 증상과 불편함을 기록하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    SymptomRecordView()
}
