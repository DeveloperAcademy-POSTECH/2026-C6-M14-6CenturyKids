import SwiftUI

struct RecordsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기록확인")
                .font(.title2.bold())

            Text("날짜별 통증과 증상, 식사와 운동 기록을 확인하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    RecordsView()
}
