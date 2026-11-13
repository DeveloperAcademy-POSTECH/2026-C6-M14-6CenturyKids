import SwiftUI

struct SymptomVoiceInputView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let question: SymptomConversationQuestion
    var transcript = ""
    var voiceState = SymptomVoiceState.thinking
    var onEnd: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    private var usesScrollableLayout: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        Group {
            if usesScrollableLayout {
                scrollableLayout
            } else {
                standardLayout
            }
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

    private var standardLayout: some View {
        VStack(spacing: 0) {
            AppNavigation.QuestionHeader(question.text, sub: question.guidance,
                                         progress: question.progress ?? 0, onClose: onEnd ?? {})
                .padding(.top, 40)
            Spacer(minLength: 24)
            voiceCard
                .background(alignment: .top) {
                    SymptomCharacterVideos(state: voiceState)
                        .frame(width: 252, height: 400)
                        .offset(y: -337)
                }
                .padding(.bottom, 79)
            switchToText.padding(.vertical, -12.5)
        }
    }

    private var scrollableLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { onEnd?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onEnd == nil)
                .accessibilityLabel("닫기")
                AppNavigation.ProgressBar(value: question.progress ?? 0)
            }
            ScrollView {
                VStack(spacing: 16) {
                    AppNavigation.QuestionHeader(question.text, sub: question.guidance)
                    SymptomCharacterVideos(state: voiceState)
                        .aspectRatio(680.0 / 1080, contentMode: .fit)
                        .frame(maxWidth: 252)
                    voiceCard
                }
                .padding(.vertical, 12)
            }
            switchToText.padding(.vertical, 8)
        }
    }

    private var voiceCard: some View {
        SymptomVoiceCard(transcript: transcript, state: voiceState, showsFullTranscript: usesScrollableLayout)
    }

    private var switchToText: some View {
        AppActions.TextButton("글로 입력할게요") { onSwitchToText?() }
            .disabled(onSwitchToText == nil)
    }
}

private struct SymptomCharacterVideos: View {
    let state: SymptomVoiceState

    var body: some View {
        ZStack {
            video("CareCallSpeaking", shows: state == .aiSpeaking)
            // 답을 분석하는 동안에도 듣던 끄덕임을 끊지 않고 이어 간다
            video("CareCallNodding", shows: state != .aiSpeaking)
        }
    }

    private func video(_ name: String, shows: Bool) -> some View {
        CareCallCharacterVideo(name: name, isPlaying: shows)
            .opacity(shows ? 1 : 0)
    }
}

private struct SymptomVoiceCard: View {
    let transcript: String
    let state: SymptomVoiceState
    let showsFullTranscript: Bool

    private static let green = Color(red: 149 / 255, green: 217 / 255, blue: 40 / 255)

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
            .lineLimit(showsFullTranscript ? nil : 2)
            .truncationMode(.head)
            .fixedSize(horizontal: false, vertical: showsFullTranscript)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("symptom.transcript")
            if isWorking || (state == .patientSpeaking && !transcript.isEmpty) {
                HStack(alignment: showsFullTranscript ? .firstTextBaseline : .center, spacing: 8) {
                    SymptomRemainingCircle(color: isWorking ? AppColors.Semantic.Text.action
                                                           : AppColors.Semantic.Text.default,
                                           duration: isWorking ? 2 : 1)
                    Text(isWorking ? "말씀을 정리하고 있어요" : "곧 넘어가요. 이어서 말씀하셔도 돼요")
                        .appTypography(.label)
                        .fixedSize(horizontal: false, vertical: showsFullTranscript)
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

private struct SymptomRemainingCircle: View {
    let color: Color
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
            let remaining = reduceMotion ? 0.75 : 1 - elapsed / duration
            ZStack {
                Circle().stroke(AppColors.Semantic.Text.default.opacity(0.15), lineWidth: 1.6)
                Circle().trim(from: 0, to: remaining)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(1)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

private struct SymptomShimmerText: View {
    let text: String
    let highlight: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
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
