#if DEBUG
import SwiftUI

/// 컴포넌트 재배치 전에 원본 이름과 조합을 확인하는 Canvas입니다.
struct ActionsPreview: View {
    @State private var actionCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Actions").appTypography(.headline)
                Text("동작 횟수: \(actionCount)")
                    .appTypography(.bodySmall)
                    .accessibilityIdentifier("actions-count")

                Text("Button").appTypography(.title)
                AppActions.Button("다음") { actionCount += 1 }
                    .accessibilityIdentifier("actions-primary")
                AppActions.Button("비활성") { actionCount += 1 }
                    .disabled(true)
                    .accessibilityIdentifier("actions-disabled")
                AppActions.Button("보조 버튼", kind: .secondary) { actionCount += 1 }

                Text("Back Button · Text Button · Icon Button").appTypography(.title)
                HStack(spacing: 20) {
                    AppActions.BackButton { actionCount += 1 }
                    AppActions.TextButton("나중에 할게요") { actionCount += 1 }
                }
                HStack(alignment: .top, spacing: 20) {
                    AppActions.IconButton("닫기", icon: Image(systemName: "xmark")) {
                        actionCount += 1
                    }
                    AppActions.IconButton("종료", icon: Image(systemName: "checkmark"), type: .labeled) {
                        actionCount += 1
                    }
                }
                Text("Bottom Action").appTypography(.title)
            }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)

            AppActions.BottomAction(
                primary: .init("완료") { actionCount += 1 },
                caption: "안내 문구를 여기에 표시합니다.",
                backAction: { actionCount += 1 },
                secondary: .init("다른 방법 선택") { actionCount += 1 },
                subAction: .init("다음에 다시 할게요") { actionCount += 1 }
            )
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .background(AppColors.Semantic.Background.surface)
    }
}

#Preview("Actions") {
    ActionsPreview()
}

#Preview("Bottom Action · Primary only") {
    Color.white.safeAreaInset(edge: .bottom) {
        AppActions.BottomAction(primary: .init("완료") {})
    }
}

#Preview("Actions · Large Text") {
    ActionsPreview().environment(\.dynamicTypeSize, .accessibility3)
}
#endif
