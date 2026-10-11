import SwiftUI

struct IntakeRecordView: View {
    var body: some View {
        AppHeader(
            title: "식사 기록",
            description: "끼니별 식사량과 선택적인 사진을 기록하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    IntakeRecordView()
}
