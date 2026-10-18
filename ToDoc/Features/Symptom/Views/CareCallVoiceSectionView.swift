import SwiftUI

/// Reusable, callback-driven rendering of the 11 frames in Figma section 1:1657.
/// The existing live CareCallFlowView keeps its automatic voice/engine behavior.
struct CareCallVoiceSectionView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let phase: CareCallVoicePhase
    @Binding var answer: String
    var transcript: String
    @Binding var summaryItems: [CareCallVoiceSummaryItem]
    @Binding var editingItemID: UUID?
    var questionText: String? = nil
    var progressValue: Double? = nil
    var showsFollowUpGuidance: Bool? = nil
    var alwaysShowsModeSwitch = false
    var onContinue: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onEnd: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onSwitchMode: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onSave: (() -> Void)?

    var body: some View {
        Group {
            switch phase {
            case .incoming:
                CareCallIncomingView(canAnswer: onContinue != nil, onAnswer: onContinue,
                    onEnd: onEnd, onPostpone: onPostpone, onSwitchToText: onSwitchMode)
            case .loading:
                SymptomSummaryLoadingView()
            case .completed:
                SymptomCompletionView(onShowRecord: onShowRecord, onHome: onEnd)
            case .summary, .editing:
                CareCallVoiceSummaryView(items: $summaryItems, editingItemID: $editingItemID,
                    onBack: onPrevious, onSave: onSave)
            default:
                question
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var isText: Bool { [.emptyText, .answer, .lastAnswer].contains(phase) }
    private var hasPrevious: Bool { phase == .answer || phase == .lastAnswer }
    private var isFirst: Bool { phase == .ready || phase == .listening }
    private var canContinue: Bool {
        onContinue != nil && (!isText || !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    private var nextTitle: String {
        switch phase {
        case .ready: "대화 시작하기"
        case .listening, .followUp: "음성 인식 중 .."
        case .lastAnswer: "완료하기"
        default: answer.isEmpty ? "답변을 입력해 주세요" : "이 답변으로 계속"
        }
    }
    private var question: some View {
        AppConversationLayout {
            VStack(spacing: AppSpacing.question) {
                AppProgressTrack(value: progressValue ?? (phase == .lastAnswer ? 1 : 86 / 354))
                VStack(spacing: AppSpacing.compact) {
                    if showsFollowUpGuidance ?? !isFirst {
                        Text("말씀해 주신 내용에 대해 조금 더 여쭤볼게요")
                            .appFont(.body)
                            .foregroundStyle(AppColors.Text.secondary)
                    }
                    Text(questionText ?? (isFirst ? "오늘 몸 상태는 좀 어떠셨어요?" : "배가 아픈 건 언제부터였나요?"))
                        .appFont(.question)
                        .tracking(-0.2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                if isText {
                    AppAnswerEditor(text: $answer, accessibilityIdentifier: "carecall.voice.answer")
                } else {
                    portrait
                    Text(phase == .ready ? "말하는 내용이 실시간으로 표시됩니다." : transcript)
                        .appFont(.body)
                        .foregroundStyle(phase == .ready ? AppColors.Text.secondary : AppColors.Text.primary)
                        .frame(maxWidth: 250, alignment: .leading)
                        .accessibilityIdentifier("carecall.voice.transcript")
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.question)
            .padding(.bottom, AppSpacing.section)
        } footer: {
            VStack(spacing: AppSpacing.section) {
                if phase != .followUp || alwaysShowsModeSwitch {
                    HStack {
                        AppCircleControl(title: "종료하기", asset: "CareConversationClose", action: onEnd)
                        Spacer()
                        AppCircleControl(title: isText ? "음성 전환" : "채팅 전환",
                            asset: "CareConversationText", action: onSwitchMode)
                    }
                }
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.item)) : AnyLayout(HStackLayout(spacing: AppSpacing.columnGap))
                layout {
                    if hasPrevious {
                        Button("이전") { onPrevious?() }
                            .buttonStyle(AppButtonStyle(kind: typeSize.isAccessibilitySize ? .secondary : .back))
                            .disabled(onPrevious == nil)
                    }
                    Button { onContinue?() } label: { AppForwardLabel(title: nextTitle, asset: "CareConversationNext") }
                        .buttonStyle(AppButtonStyle())
                        .disabled(!canContinue)
                        .accessibilityIdentifier("carecall.voice.continue")
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.compact)
            .padding(.bottom, 2)
            .background(AppColors.surface)
        }
        .background(AppColors.surface)
    }

    private var portrait: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: AppMetrics.Conversation.inputRadius)
                .fill(phase == .ready ? AppGradients.conversationPortrait : AppGradients.conversationListeningPortrait)
                .overlay(alignment: .top) {
                    if phase == .ready {
                        Image("CareCallHakro")
                            .resizable()
                            .frame(width: geometry.size.width + 27, height: geometry.size.width + 27)
                            .offset(x: -1.5, y: 13)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.Conversation.inputRadius))
        }
        .frame(height: AppMetrics.Conversation.inputHeight)
        .accessibilityHidden(true)
    }
}
