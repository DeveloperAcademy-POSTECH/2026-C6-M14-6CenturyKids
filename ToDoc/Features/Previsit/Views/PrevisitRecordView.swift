import SwiftUI

/// 기록할 날을 고르고, 하고 싶은 말과 진료 전 상태를 전송합니다.
struct PrevisitRecordView: View {
    let records: PrevisitRecordState
    var onClose: (() -> Void)?
    var onSubmit: ((PrevisitDraft) -> Void)?
    var onReload: (() -> Void)?
    @State private var session: PrevisitSession
    var isSubmitting = false
    var submissionError: String?
    @State private var showsSubmitConfirmation = false
    @State private var showsSelectedDay = false
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(days: [PrevisitDay] = [],
         initialStep: PrevisitStep = .day, initialDraft: PrevisitDraft = .init(),
         onClose: (() -> Void)? = nil, onSubmit: ((PrevisitDraft) -> Void)? = nil,
         session: PrevisitSession? = nil, records: PrevisitRecordState? = nil,
         onReload: (() -> Void)? = nil, isSubmitting: Bool = false, submissionError: String? = nil) {
        self.records = records ?? .loaded(days)
        self.onClose = onClose; self.onSubmit = onSubmit
        self.onReload = onReload
        self.isSubmitting = isSubmitting
        self.submissionError = submissionError
        let session = session ?? PrevisitSession(step: initialStep, draft: initialDraft)
        _session = State(initialValue: session)
    }

    private var step: PrevisitStep { session.step }
    private var draft: PrevisitDraft { session.draft }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    if step != .day { recordNotice }
                    switch step {
                    case .day:
                        dayList
                    case .letter:
                        letter
                    case .mood:
                        PrevisitMoodSlider(selection: draft.mood, onSelect: selectMood)
                    }
                }
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.top, step == .mood ? 40 : 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .id(step)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if writing {
                Button { writing = false } label: {
                    Text("입력 완료").appTextStyle(.label)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("previsit.finishWriting")
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 8)
                .background(AppColors.Semantic.Background.default)
            } else { footer }
        }
        .disabled(isSubmitting)
        .overlay {
            if showsSubmitConfirmation {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea().accessibilityHidden(true)
                    AppFeedback.Dialog("기록을 전송할까요?", message: "전송한 진료 전 기록은 수정하거나 삭제할 수 없어요. 내용을 확인한 뒤 전송해 주세요.",
                        primary: .init("전송하기") {
                            showsSubmitConfirmation = false
                            onSubmit?(draft)
                        }, secondary: .init("다시 확인하기") { showsSubmitConfirmation = false })
                        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                        .accessibilityAddTraits(.isModal)
                }
            }
        }
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .onAppear {
            session.analytics.screenAppeared(step: step)
            updateAnalytics()
        }
        .onChange(of: step) { _, _ in
            showsSelectedDay = false
            updateAnalytics()
        }
        .onChange(of: analyticsPauseReason) { _, _ in updateAnalytics() }
        .onDisappear { session.analytics.screenDisappeared() }
        .toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
    }
    private var header: some View {
        VStack(spacing: 8) {
            AppNavigation.PageTitle(title, alignment: .center)
            Text(subtitle)
                .appTypography(.label)
                .foregroundStyle(AppColors.Semantic.Text.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .padding(.top, 34)
        .padding(.bottom, 14)
        .overlay(alignment: .topLeading) {
            AppActions.IconButton("닫기", icon: Image("DesignSystem/Components/Navigation/Prev"), action: close)
                .padding(.leading, AppLayout.Phone.horizontalMargin)
                .padding(.top, 4)
        }
    }

    private var title: String {
        switch step {
        case .day: "가장 이야기 하고 싶은 날"
        case .letter: "진료 전 기록"
        case .mood: "진료 전 상태 선택"
        }
    }

    private var subtitle: String {
        switch step {
        case .day: "기록한 날 중 하나를 골라주세요"
        case .letter: "선생님과 어떤 이야기를 나눠보고 싶나요?"
        case .mood: "진료를 앞두고, 지금 어떤 기분인가요?"
        }
    }

    @ViewBuilder private var dayList: some View {
        switch records {
        case .loading, .failed:
            recordNotice
        case .loaded(let days):
            if days.isEmpty {
                Text("최근 30일 이내에 저장한 기록이 없어요. 통증이나 증상을 기록한 뒤 다시 열어 주세요.")
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .accessibilityIdentifier("previsit.empty")
            }
            let selectedID = currentDaySelection?.id
            LazyVStack(spacing: 36) {
                ForEach(days) { day in
                    PrevisitDayPickerCard(day: day, selected: selectedID == day.id) {
                        selectDay(day)
                    }
                }
            }
        }
    }

    @ViewBuilder private var recordNotice: some View {
        switch records {
        case .loading:
            ProgressView("저장한 기록을 불러오고 있어요.")
                .frame(maxWidth: .infinity).accessibilityIdentifier("previsit.loading")
        case .failed:
            Text("기록을 불러오지 못했어요. 다시 시도해 주세요.")
                .appTextStyle(.caption).accessibilityIdentifier("previsit.loadFailed")
            Button("다시 불러오기") { onReload?() }.buttonStyle(AppButtonStyle(kind: .secondary))
        case .loaded: EmptyView()
        }
    }
    private var letter: some View {
        VStack(spacing: 20) {
            if let day = draft.day {
                selectedDaySummary(day)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("진료 전 기록")
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                Text("선생님께 묻고 싶은 것을 편하게 적어주세요.")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)

                ZStack(alignment: .topLeading) {
                    if draft.letter.isEmpty && !writing {
                        Text("예) 오늘 너무 힘들었어요…")
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Semantic.Text.placeholder)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: Binding(
                        get: { session.draft.letter },
                        set: { session.draft.letter = String($0.prefix(200)) }
                    ))
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .scrollContentBackground(.hidden)
                    .focused($writing)
                    .padding(.horizontal, -5)
                    .frame(minHeight: 178)
                    .accessibilityLabel("선생님께 전할 이야기")
                    .accessibilityIdentifier("previsit.letter")
                }
                Text("\(draft.letter.count)/200자")
                    .appTypography(.caption)
                    .foregroundStyle(draft.letter.count >= 200 ? AppColors.Semantic.Text.error : AppColors.Semantic.Text.sub)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
        }
    }

    private func selectedDaySummary(_ day: PrevisitDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.displayDate)
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                Text(day.displayWeekday)
                    .appTypography(.label)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }

            if showsSelectedDay {
                PrevisitDayDetails(day: day, showsDate: false, allowsDisclosure: false)
            } else {
                Text(summary(for: day))
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Button {
                showsSelectedDay.toggle()
            } label: {
                Label(showsSelectedDay ? "기록 접기" : "기록 자세히 보기",
                      systemImage: showsSelectedDay ? "chevron.up" : "chevron.down")
                    .appTypography(.label)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .accessibilityIdentifier("previsit.selectedDay.details")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
    }

    private func summary(for day: PrevisitDay) -> AttributedString {
        var result = AttributedString()
        if day.symptomCount > 0 {
            result += highlighted("증상 \(day.symptomCount)개")
            result += AttributedString("를 기록했어요.")
        } else if !day.symptomRows.isEmpty {
            result += AttributedString("증상 기록이 있어요.")
        }
        if let pain = day.representativePain {
            if !result.characters.isEmpty { result += AttributedString(" ") }
            if !pain.location.isEmpty {
                result += highlighted(pain.location)
                result += AttributedString(" ")
            }

            if let after = pain.after, after != pain.before {
                result += AttributedString("통증이 ")
                result += highlighted("\(pain.before)점에서 \(after)점")
                result += AttributedString(after < pain.before ? "으로 줄었어요." : "으로 늘었어요.")
            } else {
                result += AttributedString("통증은 ")
                result += highlighted("\(pain.before)점")
                result += AttributedString(pain.after == nil ? "으로 기록했어요." : "으로 같았어요.")
            }
        }
        return result.characters.isEmpty ? AttributedString("이날 남긴 기록을 확인할 수 있어요.") : result
    }

    private func highlighted(_ text: String) -> AttributedString {
        var value = AttributedString(text)
        value.backgroundColor = AppColors.Semantic.Chart.Category.Lime.light
        return value
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.compact) {
            if isSubmitting { ProgressView("전송 중이에요") }
            if let submissionError {
                Text(submissionError).appTextStyle(.caption).foregroundStyle(.secondary)
            }
            if step == .mood, onSubmit == nil {
                Text("현재 기록을 전송할 수 없어요. 화면을 닫고 다시 시도해 주세요.")
                    .appTextStyle(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("previsit.unsent")
            }
            HStack(spacing: AppLayout.Phone.columnSpacing) {
                if step != .day {
                    AppActions.BackButton(action: previous)
                        .accessibilityIdentifier("previsit.previous")
                }
                AppActions.Button(step == .mood ? "전송하기" : "다음", action: next)
                    .disabled(!canContinue)
                    .accessibilityIdentifier("previsit.next")
            }
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .padding(.top, 12)
        .padding(.bottom, 2)
            .background(AppColors.Semantic.Background.default)
    }
    private var currentDaySelection: PrevisitDay? {
        guard case .loaded(let days) = records else { return nil }
        return days.first { $0.id == draft.day?.id && $0.isSelectable }
            ?? days.first(where: \.isSelectable)
    }

    private var canContinue: Bool {
        guard !isSubmitting, draft.letter.count <= 200, case .loaded = records else { return false }
        if step == .day { return currentDaySelection != nil }
        return session.canContinue && (step != .mood || onSubmit != nil)
    }

    private func selectDay(_ day: PrevisitDay) {
        let previousID = draft.day?.id
        session.selectDay(day)
        if let selectedID = draft.day?.id {
            session.analytics.recordSelectionChanged(from: previousID, to: selectedID)
        }
    }

    private var analyticsPauseReason: String? {
        if scenePhase != .active { return "app_inactive" }
        if isSubmitting { return "send_started" }
        if showsSubmitConfirmation { return "confirmation_opened" }
        return nil
    }

    private func updateAnalytics() {
        session.analytics.updateVisibleStep(
            step, hasMoodSelection: draft.mood != nil, pausedBy: analyticsPauseReason
        )
    }

    private func selectMood(_ mood: StateOfMind) {
        let previousMood = draft.mood
        guard previousMood != mood else { return }
        updateAnalytics()
        session.draft.mood = mood
        session.analytics.recordMoodSelection(replacingSelection: previousMood != nil)
    }

    private func next() {
        guard canContinue else { return }
        writing = false
        if step == .mood {
            session.analytics.endActiveInterval(reason: "confirmation_opened")
            showsSubmitConfirmation = true
        } else {
            let from = step
            if from == .day, let day = currentDaySelection { selectDay(day) }
            session.next()
            session.analytics.recordStepAdvance(from: from, to: step, message: draft.letter)
        }
    }

    private func previous() {
        let from = step
        session.previous()
        session.analytics.recordStepBack(from: from, to: step, hasMoodSelection: draft.mood != nil)
    }

    private func close() {
        guard !isSubmitting else { return }
        session.analytics.recordClose(step: step, hasMoodSelection: draft.mood != nil)
        if let onClose { onClose() } else { dismiss() }
    }
}
