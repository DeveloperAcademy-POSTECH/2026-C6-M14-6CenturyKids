#if DEBUG
import SwiftUI

/// 예시 데이터만 사용하는 Figma 섹션별 Canvas. 완료도 로컬 화면 전환입니다.
struct PrevisitSectionPreview: View {
    enum Screen: String, CaseIterable {
        case entry, prompt, days, selectedDay, letter, writtenLetter, mood, selectedMood, completed
    }
    @State private var screen: Screen = .prompt
    @State private var completed: PrevisitDraft?
    init(initialScreen: Screen = .prompt) {
        _screen = State(initialValue: initialScreen)
    }
    static let days: [PrevisitDay] = {
        let pain = PrevisitDay.PainRow(location: "복부 및 등", before: 7, after: 3)
        let symptoms = [
            PrevisitDay.SymptomRow(label: "설사",
                detail: "아침에는 나아지는 것 같았는데 저녁에 배가 다시 불편했어요.\n저녁을 먹고 나서는 한동안 화장실을 자주 갔어요.",
                entry: "설사 · 아침에는 나아지는 것 같았는데 저녁에 배가 다시 불편했어요.\n저녁을 먹고 나서는 한동안 화장실을 자주 갔어요."),
            PrevisitDay.SymptomRow(label: "두통", detail: "어지럽고 머리가 지끈거렸어요.",
                                  entry: "두통 · 어지럽고 머리가 지끈거렸어요.")
        ]
        return [
            .init(id: "18", dateLabel: "10월 18일", weekday: "일요일",
                  entries: symptoms.map(\.entry) + [pain.entry], recordedDate: .now,
                  painBefore: 7, painAfter: 3, symptomCount: 2,
                  painRows: [pain], symptomRows: symptoms, representativePain: pain),
            .init(id: "17", dateLabel: "10월 17일", weekday: "토요일",
                  entries: ["설사 3회"], symptomCount: 1),
            .init(id: "16", dateLabel: "10월 16일", weekday: "금요일", entries: [])
        ]
    }()
    static let sampleLetter = "최근 속이 불편했던 날이 있어요. 진료 때 함께 이야기 나누고 싶어요."
    var body: some View {
        Group {
            switch screen {
            case .entry, .prompt, .completed:
                entry.allowsHitTesting(screen == .entry).accessibilityHidden(screen != .entry)
                    .sheet(isPresented: .constant(screen == .prompt)) {
                        PrevisitPromptView(onStart: { screen = .days }, onClose: { screen = .entry })
                    }.overlay {
                    if screen == .completed {
                        PrevisitPromptView(completedDraft: completed ?? draft, onClose: { screen = .entry })
                    }
                }
            default:
                PrevisitRecordView(days: Self.days,
                    initialStep: step, initialDraft: draft, onClose: { screen = .entry },
                    onSubmit: { completed = $0; screen = .completed }).id(screen)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("화면 미리보기 · 실제 전송 안 됨")
                .appTextStyle(.caption)
                .foregroundStyle(AppColors.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(AppColors.surface)
        }
        .preferredColorScheme(.light)
    }
    // 홈 진입 연결은 별도 Home PR에서 다룹니다. 이 버튼은 Preview 전용입니다.
    private var entry: some View {
        VStack(spacing: AppSpacing.section) {
            Text("진료 전 기록 미리보기").appTextStyle(.heading)
            Button("안내부터 시작하기") { screen = .prompt }
                .buttonStyle(AppButtonStyle())
        }
        .padding(AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surface)
    }
    private var step: PrevisitStep {
        switch screen {
        case .letter, .writtenLetter: .letter
        case .mood, .selectedMood: .mood
        default: .day
        }
    }
    private var draft: PrevisitDraft {
        .init(day: screen == .days ? nil : Self.days[1],
              letter: [.writtenLetter, .mood, .selectedMood, .completed].contains(screen) ? Self.sampleLetter : "",
              mood: [.selectedMood, .completed].contains(screen) ? .comfortable : nil)
    }
}
#Preview("진료 전 기록 · 안내부터") { PrevisitSectionPreview() }
#Preview("기록 선택 전 · 417:19245") { PrevisitSectionPreview(initialScreen: .days) }
#Preview("기록 선택 · 417:19189") { PrevisitSectionPreview(initialScreen: .selectedDay) }
#Preview("편지 작성 · 200:3445 · 키보드는 입력란 탭") { PrevisitSectionPreview(initialScreen: .letter) }
#Preview("작성한 편지 · 200:3478") { PrevisitSectionPreview(initialScreen: .writtenLetter) }
#Preview("기분 선택 전 · 200:3838") { PrevisitSectionPreview(initialScreen: .mood) }
#Preview("기분 선택 · 200:3894") { PrevisitSectionPreview(initialScreen: .selectedMood) }
#Preview("진료 전 안내 · 200:3658") { PrevisitSectionPreview(initialScreen: .prompt) }
#Preview("전송 완료 예시 · 200:3724") { PrevisitSectionPreview(initialScreen: .completed) }
#endif
