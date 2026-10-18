#if DEBUG
import SwiftUI

/// 예시 데이터만 사용하는 Figma 섹션별 Canvas. 완료도 로컬 화면 전환입니다.
struct PrevisitSectionPreview: View {
    enum Screen: String, CaseIterable {
        case entry, prompt, days, selectedDay, letter, writtenLetter, mood, selectedMood, completed
    }
    var initialScreen: Screen = .prompt
    @State private var screen: Screen = .prompt
    @State private var completed: PrevisitDraft?
    init(initialScreen: Screen = .prompt) {
        self.initialScreen = initialScreen
        _screen = State(initialValue: initialScreen)
    }
    static let days: [PrevisitDay] = [
        .init(id: "17", dateLabel: "10/17", weekday: "토요일", entries: ["설사 3회, 거의 화장실에서 살았다"]),
        .init(id: "18", dateLabel: "10/18", weekday: "일요일", entries: ["설사 3회, 거의 화장실에서 살았다", "어지러움, 머리가 지끈지끈", "복부통증 7 → 3"]),
        .init(id: "19", dateLabel: "10/19", weekday: "월요일", entries: []),
        .init(id: "20", dateLabel: "10/20", weekday: "화요일", entries: [])
    ]
    static let sampleLetter = "그 날은 진짜 배가 짱! 아팠어요 장이 꼬이는 느낌? 아니 이건 겪어봐야 알아. 배가 꾸륵꾸륵~ 먹은 것도 없는데 자꾸 왜 이러는 건지 모르겠네 의사 네가 내 아픔을 알아? 열받네"
    var body: some View {
        Group {
            switch screen {
            case .entry, .prompt, .completed:
                entry.allowsHitTesting(screen == .entry).accessibilityHidden(screen != .entry).overlay {
                    if screen == .prompt {
                        PrevisitPromptView(onStart: { screen = .days }, onClose: { screen = .entry })
                    } else if screen == .completed {
                        PrevisitPromptView(completedDraft: completed ?? draft, doctorName: "학로쌤", patientName: "최연우", onClose: { screen = .entry })
                    }
                }
            default:
                PrevisitRecordView(days: Self.days, doctorName: "학로쌤", patientName: "최연우",
                    initialStep: step, initialDraft: draft, onClose: { screen = .entry },
                    onSubmit: { completed = $0; screen = .completed }).id(screen)
            }
        }.preferredColorScheme(.light)
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
#Preview("날짜 선택 전 · 200:3602") { PrevisitSectionPreview(initialScreen: .days) }
#Preview("날짜 선택 · 200:3546") { PrevisitSectionPreview(initialScreen: .selectedDay) }
#Preview("편지 작성 · 200:3445 · 키보드는 입력란 탭") { PrevisitSectionPreview(initialScreen: .letter) }
#Preview("작성한 편지 · 200:3478") { PrevisitSectionPreview(initialScreen: .writtenLetter) }
#Preview("기분 선택 전 · 200:3838") { PrevisitSectionPreview(initialScreen: .mood) }
#Preview("기분 선택 · 200:3894") { PrevisitSectionPreview(initialScreen: .selectedMood) }
#Preview("진료 전 안내 · 200:3658") { PrevisitSectionPreview(initialScreen: .prompt) }
#Preview("전송 완료 예시 · 200:3724") { PrevisitSectionPreview(initialScreen: .completed) }
#endif
