import SwiftUI

/// Figma 증상 대화 음성(1766:28140 듣는 중, 1766:28153 정리 중). 통화는 화면에 들어오고 1초 뒤 자동으로 걸립니다.
/// 카드 뒤에서 학로 영상이 차례(voiceState)에 맞춰 바뀝니다.
struct SymptomVoiceInputView: View {
    let question: SymptomConversationQuestion
    var transcript = ""
    /// 지금 누구 차례인지. 캐릭터 영상도 이 값으로 고른다
    var voiceState = SymptomVoiceState.thinking
    var onEnd: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            AppNavigation.QuestionHeader(question.text, sub: question.guidance,
                                         progress: question.progress ?? 0, onClose: onEnd ?? {})
                .padding(.top, 40)
            Spacer(minLength: 24)
            SymptomVoiceCard(transcript: transcript, state: voiceState)
                .background(alignment: .top) {
                    // Figma에서 머리 위가 카드 위 337 위, 다리는 카드 뒤로 들어간다 (영상 680×1080)
                    SymptomCharacterVideos(state: voiceState)
                        .frame(width: 252, height: 400)
                        .offset(y: -337)
                }
                .padding(.bottom, 79)
            // Figma Bottom Action의 보조 액션 글자. 누르는 영역 44는 위아래로 겹친다
            AppActions.TextButton("글로 입력할게요") { onSwitchToText?() }
                .disabled(onSwitchToText == nil)
                .padding(.vertical, -12.5)
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) {
            LinearGradient(stops: [
                .init(color: .white, location: 0.58173),
                .init(color: Color(red: 239 / 255, green: 251 / 255, blue: 212 / 255), location: 0.71154),
                .init(color: Color(red: 237 / 255, green: 242 / 255, blue: 235 / 255), location: 0.875)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// 차례별 영상 3개를 미리 띄워 두고 지금 차례만 보이고 재생한다 (바뀔 때 빈 화면이 생기지 않게)
private struct SymptomCharacterVideos: View {
    let state: SymptomVoiceState

    var body: some View {
        ZStack {
            video("CareCallSpeaking", for: .aiSpeaking)
            video("CareCallNodding", for: .patientSpeaking)
            video("CareCallThinking", for: .thinking)
        }
    }

    private func video(_ name: String, for owner: SymptomVoiceState) -> some View {
        CareCallCharacterVideo(name: name, isPlaying: state == owner)
            .opacity(state == owner ? 1 : 0)
    }
}

/// 환자 말 카드. 말하기 전 안내 → 듣는 중(곧 넘어가요) → 정리 중(초록 테두리)
private struct SymptomVoiceCard: View {
    let transcript: String
    let state: SymptomVoiceState

    private static let green = Color(red: 149 / 255, green: 217 / 255, blue: 40 / 255)

    /// 환자 말을 다 듣고 정리하는 중. 첫 질문을 준비할 때는 들은 말이 없어 안내 문구를 보여 준다
    private var isWorking: Bool { state == .thinking && !transcript.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if transcript.isEmpty {
                    Text("말하는 내용이 실시간으로 표시됩니다.")
                        .foregroundStyle(AppColors.Semantic.Text.placeholder)
                } else if isWorking {
                    SymptomShimmerText(text: transcript, highlight: Self.green)
                } else {
                    Text(transcript)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                }
            }
            .appTypography(.labelLarge)
            // 보이는 2줄. 길어지면 앞을 줄여 지금 하는 말이 보이게
            .lineLimit(2)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("symptom.transcript")
            if isWorking || (state == .patientSpeaking && !transcript.isEmpty) {
                HStack(spacing: 8) {
                    SymptomRemainingCircle(color: isWorking ? AppColors.Semantic.Text.action
                                                           : AppColors.Semantic.Text.default,
                                           duration: isWorking ? 2 : 1)
                    Text(isWorking ? "말씀을 정리하고 있어요" : "곧 넘어가요. 이어서 말씀하셔도 돼요")
                        .appTypography(.label)
                        .foregroundStyle(isWorking ? AppColors.Semantic.Text.action : AppColors.Semantic.Text.sub)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            if isWorking {
                RoundedRectangle(cornerRadius: 28).strokeBorder(Self.green, lineWidth: 2.5)
            }
        }
        .shadow(color: isWorking ? Self.green.opacity(0.35) : .clear, radius: 9)
        .accessibilityElement(children: .combine)
    }
}

/// 남은 시간 원. 바퀴가 duration 동안 줄어들기를 되풀이한다.
// ponytail: 실제 침묵 시간과 맞추지 않은 표시용. 말이 멈춘 순간부터 줄이려면 음성 어댑터의 침묵 시작 신호가 필요
private struct SymptomRemainingCircle: View {
    let color: Color
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
            let remaining = reduceMotion ? 0.75 : 1 - elapsed / duration
            ZStack {
                Circle().stroke(AppColors.Semantic.Text.default.opacity(0.18), lineWidth: 2)
                Circle().trim(from: 0, to: remaining)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(1)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

/// 정리 중인 말 위로 초록 빛이 왼쪽에서 오른쪽으로 지나간다 (Figma 30–45–60% 띠)
private struct SymptomShimmerText: View {
    let text: String
    let highlight: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            // 띠가 1.6초마다 글 왼쪽 밖에서 오른쪽 밖으로 지나간다
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.6) / 1.6 * 2 - 1
            Text(text).foregroundStyle(LinearGradient(stops: [
                .init(color: AppColors.Semantic.Text.default, location: 0.3),
                .init(color: highlight, location: 0.45),
                .init(color: AppColors.Semantic.Text.default, location: 0.6)
            ], startPoint: UnitPoint(x: phase, y: 0.5), endPoint: UnitPoint(x: phase + 1, y: 0.5)))
        }
    }
}

#Preview("듣는 중") {
    SymptomVoiceInputView(question: .init(id: UUID(), text: "오늘 컨디션은 어떠세요?",
                                          guidance: "지금부터 AI음성으로 오늘 몸 상태를 여쭤볼게요.",
                                          progress: 0.25, input: .text),
                          transcript: "어제 저녁부터 배가 살살 아프고 밤에 두 번 정도 깼어요", voiceState: .patientSpeaking,
                          onEnd: {}, onSwitchToText: {})
}

#Preview("정리 중") {
    SymptomVoiceInputView(question: .init(id: UUID(), text: "배가 아픈 건 언제부터였나요?",
                                          guidance: "말씀해주신 내용에 대해 조금 더 여쭤볼게요",
                                          progress: 0.4, input: .text),
                          transcript: "항암제를 맞고 이틀 정도 후 부터 아프기 시작한 것 같아요.", voiceState: .thinking,
                          onEnd: {}, onSwitchToText: {})
}

#Preview("말하기 전") {
    SymptomVoiceInputView(question: .init(id: UUID(), text: "오늘 컨디션은 어떠세요?",
                                          guidance: nil, progress: nil, input: .text),
                          onEnd: {}, onSwitchToText: {})
}
