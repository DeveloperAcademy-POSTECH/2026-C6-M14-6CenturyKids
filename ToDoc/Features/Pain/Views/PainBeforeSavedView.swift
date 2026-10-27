import SwiftUI

/// 먹기 전 통증을 저장한 뒤, 1시간 뒤에 이어서 기록하도록 안내합니다.
struct PainBeforeSavedView: View {
    let before: Int
    var onHome: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: 8) {
                Text("1시간 뒤에 알려드릴게요")
                    .modifier(PainTextStyle(size: 24, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("약 복용 전 통증을 \(before)점으로 기록했어요.\n약을 드시고 1시간이 지나면 복용 후 통증을 기록해 주세요.")
                    .modifier(PainTextStyle(size: 15)).foregroundStyle(Color(white: 114 / 255))
            }
            .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            Button("홈으로") { onHome?() }
                .buttonStyle(AppButtonStyle()).disabled(onHome == nil)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    PainBeforeSavedView(before: 7, onHome: {})
}
