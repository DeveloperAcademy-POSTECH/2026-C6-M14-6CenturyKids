import SwiftUI

extension AppFeedback {
    /// 완료·오류 화면에서 사용하는 Figma 원본 상태 아이콘입니다.
    struct StatusIcon: View {
        enum Kind {
            case success
            case error
        }

        let kind: Kind
        var size: CGFloat = 160

        var body: some View {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }

        private var assetName: String {
            switch kind {
            case .success: "DesignSystem/Components/Feedback/Success"
            case .error: "DesignSystem/Components/Feedback/Error"
            }
        }
    }
}

#Preview("완료 · 오류 상태 아이콘") {
    HStack(spacing: 24) {
        AppFeedback.StatusIcon(kind: .success)
        AppFeedback.StatusIcon(kind: .error)
    }
    .padding()
}
