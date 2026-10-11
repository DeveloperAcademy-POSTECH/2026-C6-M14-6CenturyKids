import SwiftUI

struct PainRecordView: View {
    var body: some View {
        AppHeader(
            title: "통증 기록",
            description: "약 복용 전후의 통증 변화를 기록하는 화면입니다."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appScreenStyle()
    }
}

#Preview {
    PainRecordView()
}
