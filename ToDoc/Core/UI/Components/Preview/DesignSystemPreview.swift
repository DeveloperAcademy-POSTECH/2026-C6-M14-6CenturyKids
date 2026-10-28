#if DEBUG
import SwiftUI

/// Figma 섹션 순서의 최신 컴포넌트 목록. 앱 화면 교체 전 Canvas에서 먼저 확인합니다.
struct DesignSystemPreview: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Actions") {
                    NavigationLink("Button · Bottom Action · Back · Text · Icon") { ActionsPreview() }
                }
                Section("Inputs") {
                    NavigationLink("Text Field · Text Area") { InputsPreview() }
                    NavigationLink("Chip · Checkbox · Radio · Segmented · Wheel") {
                        InputsPreview(selectionOnly: true)
                    }
                }
                Section("Navigation & Headers") {
                    NavigationLink("Header · Progress · Date · Tab") { NavigationPreview() }
                }
                Section("Display & Feedback") {
                    NavigationLink("Avatar · Status Tag · Toast · Dialog") { FeedbackPreview() }
                }
                Section("Cards & Lists") {
                    NavigationLink("Mood · Row · List · Notification · Note") { CardsPreview() }
                    NavigationLink("Summary · Menu · Chart · Day Record") { CardsPreview(summaryOnly: true) }
                }
                Text("Preview 예시 · 실제 저장·전송 없음")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }
            .navigationTitle("Design System")
        }
    }
}

struct FeedbackPreview: View {
    @State private var actionCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preview 예시 · 실행 횟수 \(actionCount)")
                    .appTypography(.caption)
                title("Avatar")
                HStack(spacing: 16) {
                    ForEach(AppFeedback.Avatar.Mood.allCases) { mood in
                        AppFeedback.Avatar(mood: mood)
                    }
                }
                title("Status Tag")
                AppFeedback.StatusTag("하루 2회 · 예시")
                AppFeedback.StatusTag("기록 없음", showsDot: false)
                title("Toast")
                AppFeedback.Toast("입력 내용을 확인했어요 · 예시")
                title("Dialog / Text")
                AppFeedback.Dialog("이어서 작성할까요?", message: "대화상자의 버튼 동작을 확인하는 예시입니다.",
                                   style: .text, primary: .init("확인") { actionCount += 1 },
                                   secondary: .init("취소") { actionCount += 1 })
                    .frame(maxWidth: .infinity)
                title("Dialog / Button")
                AppFeedback.Dialog("기록을 이어서 작성해요", message: "실제 저장이나 전송은 하지 않습니다.",
                                   style: .button, primary: .init("계속하기") { actionCount += 1 },
                                   secondary: .init("나중에 하기") { actionCount += 1 })
                    .frame(maxWidth: .infinity)
            }
            .padding(AppLayout.Phone.horizontalMargin)
        }
        .background(AppColors.Semantic.Background.secondary)
        .navigationTitle("Display & Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func title(_ text: String) -> some View {
        Text(text).appTypography(.labelLarge).accessibilityAddTraits(.isHeader)
    }
}

struct CardsPreview: View {
    var summaryOnly = false
    @State private var selectedMood = false
    @State private var selectedDay = false
    @State private var actionCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preview 예시 · 실제 저장·전송 없음 · 실행 \(actionCount)")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                if summaryOnly { summaryCards } else { basicCards }
            }
            .padding(AppLayout.Phone.horizontalMargin)
        }
        .background(AppColors.Semantic.Background.secondary)
        .navigationTitle("Cards & Lists")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var basicCards: some View {
        Group {
            title("Mood Option")
            AppCards.MoodOption("차분히 이야기를 들을 수 있어요", sub: "지금 마음은",
                                avatar: .init(mood: .calm), isSelected: selectedMood) {
                selectedMood.toggle()
            }
            title("Row · List Group")
            AppCards.ListGroup("설정 목록 예시") {
                AppCards.Row("알림", value: "켜짐") { actionCount += 1 }
                AppCards.Row("연결 관리", value: "예시 병원") { actionCount += 1 }
                AppCards.Row("앱 버전", value: "미리보기")
            }
            title("Notification Card")
            AppCards.NotificationCard("오늘의 안내를 확인해 주세요.", source: "의료진 예시", time: "오전 10:00",
                                      avatar: .init(mood: .calm)) { actionCount += 1 }
            title("Note Card")
            AppCards.NoteCard("진료 때 궁금한 내용을 이야기하고 싶어요.\n이 내용은 Preview용 예시입니다.",
                              to: "To. 주치의", from: "From. 예시 사용자")
        }
    }

    private var summaryCards: some View {
        Group {
            title("Symptom Summary Card")
            AppCards.SymptomSummaryCard("증상 이름 예시", description: "기록한 내용을 보여주는 예시입니다.",
                                        status: .init("하루 2회"))
            title("Record Summary Card")
            AppCards.RecordSummaryCard("기록 요약", description: "자세한 내용을 확인해요",
                                       image: Image("Auth/Patient")) { actionCount += 1 }
            title("Menu Card")
            AppCards.MenuCard("증상 기록하기", description: "지금 상태를 남겨요", style: .primary) { actionCount += 1 }
            AppCards.MenuCard("기록 확인하기", description: "남긴 기록을 살펴봐요") { actionCount += 1 }
            title("Chart Card")
            AppCards.ChartCard("차트 영역 예시", overline: "가상 데이터", period: "10월 20일–26일") {
                sampleChart
            }
            title("Day Record Card")
            AppCards.DayRecordCard(day: "10월 27일", weekday: "화요일", records: ["증상 기록 예시", "통증 기록 예시"],
                                   emptyText: "기록이 없어요", isSelected: selectedDay, showsRadio: true) { selectedDay.toggle() }
            AppCards.DayRecordCard(day: "10월 26일", weekday: "월요일", records: [], emptyText: "기록이 없어요") {}
        }
    }

    private var sampleChart: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array([72.0, 120, 96, 144, 88, 60, 100].enumerated()), id: \.offset) { item in
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.Semantic.Primary.default)
                    .frame(maxWidth: .infinity)
                    .frame(height: item.element)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("가상 데이터로 표시한 막대 차트 예시")
    }

    private func title(_ text: String) -> some View {
        Text(text).appTypography(.labelLarge).accessibilityAddTraits(.isHeader)
    }
}

#Preview("Design System / Sections") { DesignSystemPreview() }
#Preview("Display & Feedback") { NavigationStack { FeedbackPreview() } }
#Preview("Cards & Lists") { NavigationStack { CardsPreview() } }
#Preview("Cards & Lists / Summary") { NavigationStack { CardsPreview(summaryOnly: true) } }
#endif
