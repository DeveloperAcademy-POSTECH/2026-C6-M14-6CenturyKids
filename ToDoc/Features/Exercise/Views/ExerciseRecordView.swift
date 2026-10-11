import SwiftUI

struct ExerciseRecordView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("운동 기록")
                .font(.title2.bold())

            Text("운동 목표를 확인하고 실천한 날짜를 기록하는 화면입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    ExerciseRecordView()
}
