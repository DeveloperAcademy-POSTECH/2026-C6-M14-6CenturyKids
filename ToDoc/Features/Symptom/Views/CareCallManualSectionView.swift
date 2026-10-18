import SwiftUI

/// Native inputs for the current manual-entry questions. No VM, microphone, or repository dependency.
struct CareCallManualSectionView: View {
    let step: CareCallManualStep
    @Binding var draft: CareCallManualDraft
    var questionText: String? = nil
    var progressValue: Double = 86 / 354
    var onNext: (() -> Void)?
    var onSkip: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AppConversationLayout {
            VStack(spacing: AppSpacing.question) {
                AppProgressTrack(value: progressValue)
                VStack(spacing: AppSpacing.compact) {
                    if step != .symptoms {
                        Text("말씀해 주신 내용에 대해 조금 더 여쭤볼게요")
                            .appFont(.body)
                            .foregroundStyle(AppColors.Text.secondary)
                    }
                    Text(questionText ?? step.question)
                        .appFont(.question)
                        .tracking(-0.2)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                input
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.question)
            .padding(.bottom, AppSpacing.section)
        } footer: {
            controls
        }
        .background(AppColors.surface)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var input: some View {
        switch step {
        case .symptoms:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.columnGap),
                count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                ForEach(CareCallManualSymptom.allCases) { symptom in
                    symptomButton(symptom)
                }
            }
        case .dailyLife, .other:
            textInput
        case .frequency:
            VStack(spacing: 30) {
                SymptomNumberWheel(title: "횟수", labels: (0...10).map(String.init) + ["10+"],
                    selectedIndex: draft.frequencyIndex, hasSelection: draft.answeredSteps.contains(.frequency)) {
                        draft.frequencyIndex = $0
                        draft.answeredSteps.insert(.frequency)
                    }
                Text("번 했어요").appFont(.sectionTitle)
            }
        case .duration:
            HStack(spacing: AppSpacing.columnGap) {
                VStack(spacing: 30) {
                    SymptomNumberWheel(title: "지속 시간", labels: (0...24).map(String.init),
                        selectedIndex: draft.hours, hasSelection: draft.answeredSteps.contains(.duration)) {
                            draft.hours = $0
                            draft.answeredSteps.insert(.duration)
                        }
                    Text("시간").appFont(.sectionTitle)
                }
                VStack(spacing: 30) {
                    SymptomNumberWheel(title: "지속 시간 분", labels: stride(from: 0, through: 55, by: 5).map(String.init),
                        selectedIndex: draft.minutes / 5, hasSelection: draft.answeredSteps.contains(.duration)) {
                            draft.minutes = $0 * 5
                            draft.answeredSteps.insert(.duration)
                        }
                    Text("분").appFont(.sectionTitle)
                }
            }
            .padding(.horizontal, 5)
        }
    }

    private func symptomButton(_ symptom: CareCallManualSymptom) -> some View {
        let selected = draft.symptoms.contains(symptom)
        return Button {
            if selected { draft.symptoms.remove(symptom) } else { draft.symptoms.insert(symptom) }
        } label: {
            Text(symptom.title)
                .appFont(selected ? .bodyStrong : .body)
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? AppColors.Button.primaryForeground : AppColors.Text.control)
                .frame(maxWidth: .infinity, minHeight: AppMetrics.PillButton.height)
                .background(selected ? AppColors.primary : AppColors.Surface.control, in: Capsule())
                .overlay(Capsule().stroke(selected ? AppColors.CareCall.selectionBorder : AppColors.surface, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("carecall.manual.symptom.\(symptom.rawValue)")
    }

    private var textInput: some View {
        let text = Binding<String>(
            get: { step == .dailyLife ? draft.dailyLife : draft.other },
            set: {
                if step == .dailyLife { draft.dailyLife = $0 } else { draft.other = $0 }
                draft.answeredSteps.insert(step)
            })
        return AppAnswerEditor(text: text, accessibilityLabel: questionText ?? step.question,
                               accessibilityIdentifier: "carecall.manual.answer")
    }

    private var controls: some View {
        VStack(spacing: AppSpacing.section) {
            HStack(alignment: .bottom) {
                AppCircleControl(title: "종료하기", asset: "CareConversationClose", action: onEnd)
                Spacer(minLength: 8)
                if step.allowsSkipping {
                    Button("이번 질문은 넘어가기") { onSkip?() }
                        .appFont(.captionRegular)
                        .underline()
                        .foregroundStyle(AppColors.Text.secondary)
                        .buttonStyle(.plain)
                        .disabled(onSkip == nil)
                        .frame(minHeight: 44, alignment: .bottom)
                        .accessibilityIdentifier("carecall.manual.skip")
                    Spacer(minLength: 8)
                }
                AppCircleControl(title: "음성 전환", asset: "CareConversationText", action: onSwitchToVoice)
            }
            if draft.canContinue(step) {
                Button { onNext?() } label: {
                    AppForwardLabel(title: step == .symptoms || step == .other ? "완료하기" : "이 답변으로 계속", asset: "CareConversationNext")
                }
                .buttonStyle(AppButtonStyle())
                .disabled(onNext == nil)
                .accessibilityIdentifier("carecall.manual.continue")
            } else {
                // This manual-only Figma state has its own quieter palette and regular label.
                CareCallManualPendingButton()
                    .accessibilityIdentifier("carecall.manual.continue")
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.compact)
        .padding(.bottom, 2)
        .background(AppColors.surface)
    }
}
