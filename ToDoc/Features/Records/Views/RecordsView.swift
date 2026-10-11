import SwiftUI

struct RecordsView: View {
    var body: some View {
        AppHeader(
            title: "기록확인",
            description: "날짜별 통증과 증상, 식사와 운동 기록을 확인하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    RecordsView()
}
