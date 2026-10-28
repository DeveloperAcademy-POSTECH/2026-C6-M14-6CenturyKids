#if DEBUG
import SwiftUI

/// Navigation & Headers의 표시·이동 상태 예시입니다. 실제 화면 이동은 실행하지 않습니다.
struct NavigationPreview: View {
    @State private var step = 2
    @State private var dayOffset = 0
    @State private var tab = "홈"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preview 예시 · 실제 화면과 연결되지 않음")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                AppNavigation.Header("Header", description: "섹션 제목과 보조 설명")
                AppNavigation.PageTitle("Page Title", description: "페이지를 소개하는 설명입니다.")
                AppNavigation.PageTitle("가운데 페이지 제목", alignment: .center, overline: "Overline")
                AppNavigation.QuestionHeader("오늘은 어떻게 지내셨나요?", sub: "Question Header", progress: Double(step) / 5)
                AppNavigation.ProgressBar(value: Double(step) / 5)
                HStack {
                    AppNavigation.StepIndicator(current: step, total: 5)
                    Spacer()
                    AppNavigation.StepIndicator(current: step, total: 5, style: .dots)
                }
                AppActions.TextButton("다음 단계 예시 · 현재 \(step)/5") { step = step % 5 + 1 }
                AppNavigation.DateNavigator("예시 날짜 \(dayOffset)",
                    isPreviousEnabled: dayOffset > -2, isNextEnabled: dayOffset < 2,
                    onPrevious: { dayOffset -= 1 }, onNext: { dayOffset += 1 })
                AppNavigation.TabBar(selection: $tab, options: ("홈", "기록", "설정"), title: { $0 }, icon: tabIcon)
                Text("현재 탭 · \(tab)\n아이콘은 기존 앱 에셋을 넣은 Preview 예시입니다.")
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
            .padding(.vertical, 24)
        }
        .background(AppColors.Semantic.Background.default)
        .navigationTitle("Navigation & Headers")
    }

    private func tabIcon(_ value: String) -> Image {
        switch value {
        case "홈": Image("HomeBell")
        case "기록": Image("RecordsCompletedCheck")
        default: Image("SettingsChevron")
        }
    }
}

#Preview("Navigation & Headers") { NavigationStack { NavigationPreview() } }
#endif
