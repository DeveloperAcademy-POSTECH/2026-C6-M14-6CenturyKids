import SwiftUI

struct SymptomRecordView: View {
    var body: some View {
        AppHeader(
            title: "하루 안부 기록",
            description: "하루 동안 느낀 증상과 불편함을 기록하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    SymptomRecordView()
}
