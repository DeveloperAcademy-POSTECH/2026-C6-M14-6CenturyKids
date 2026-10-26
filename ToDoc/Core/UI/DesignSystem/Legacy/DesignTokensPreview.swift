#if DEBUG
import SwiftUI

/// 공통 스타일 확인용이며 제품의 화면 전환에 연결하지 않습니다.
struct DesignTokensPreview: View {
    var body: some View {
        ScrollView {
            samples
        }
        .appScreenStyle()
    }

    var samples: some View {
        VStack(spacing: AppSpacing.ButtonGroup.captionToButtons) {
            AppHeader(title: "디자인 시스템", description: "온보딩부터 모든 환자 화면에 공통 적용")
            HStack {
                ForEach(palette, id: \.name) { item in
                    VStack {
                        Circle().fill(item.color).frame(width: 32, height: 32)
                        Text(item.name).appTextStyle(.caption)
                    }
                }
            }
            Text("Heading · 오늘의 몸 상태")
                .appTextStyle(.heading)
            Text("Label · 다음 단계로 이동")
                .appTextStyle(.label)
            Text("Caption · 내용을 확인해 주세요")
                .appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
            VStack(spacing: AppSpacing.ButtonGroup.verticalGap) {
                Button("다음") {}.buttonStyle(AppButtonStyle())
                Button("답변을 입력해 주세요") {}
                    .buttonStyle(AppButtonStyle()).disabled(true)
                Button("홈으로") {}.buttonStyle(AppButtonStyle(kind: .secondary))
                HStack(spacing: AppSpacing.ButtonGroup.horizontalGap) {
                    Button("이전") {}.buttonStyle(AppButtonStyle(kind: .back))
                    Button("이 답변으로 계속") {}.buttonStyle(AppButtonStyle())
                }
            }
            Text("이번 질문은 넘어가기")
                .appTextStyle(.label)
                .foregroundStyle(AppColors.Text.subAction)
                .padding(.top, AppSpacing.ButtonGroup.buttonsToSubAction
                         - AppSpacing.ButtonGroup.captionToButtons)
        }
        .foregroundStyle(AppColors.Text.primary)
        .padding(.bottom, AppSpacing.ButtonGroup.captionToButtons)
    }

    private var palette: [(name: String, color: Color)] {
        [("주요", AppColors.primary), ("비활성", AppColors.disabled),
         ("보조", AppColors.secondary), ("회색", AppColors.gray),
         ("배경", AppColors.background)]
    }
}

#Preview("공통 디자인 시스템") {
    DesignTokensPreview()
}

#Preview("큰 글자 · 좁은 화면", traits: .fixedLayout(width: 320, height: 800)) {
    DesignTokensPreview().environment(\.dynamicTypeSize, .accessibility3)
}
#endif
