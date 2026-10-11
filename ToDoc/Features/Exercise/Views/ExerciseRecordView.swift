import SwiftUI

struct ExerciseRecordView: View {
    var body: some View {
        AppHeader(
            title: "운동 기록",
            description: "운동 목표를 확인하고 실천한 날짜를 기록하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    ExerciseRecordView()
}
