import SwiftUI

/// Figma 417:19245·417:19189. 저장된 하루 기록을 선택한 뒤 이야기를 작성합니다.
struct PrevisitRecordView: View {
    let records: PrevisitRecordState
    var doctorName = "선생님"
    var patientName = ""
    var onClose: (() -> Void)?
    var onSubmit: ((PrevisitDraft) -> Void)?
    var onReload: (() -> Void)?
    @State private var session: PrevisitSession
    var isSubmitting = false
    var submissionError: String?
    @State private var showsSubmitConfirmation = false
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    init(days: [PrevisitDay] = [], doctorName: String = "선생님", patientName: String = "",
         initialStep: PrevisitStep = .day, initialDraft: PrevisitDraft = .init(),
         onClose: (() -> Void)? = nil, onSubmit: ((PrevisitDraft) -> Void)? = nil,
         session: PrevisitSession? = nil, records: PrevisitRecordState? = nil,
         onReload: (() -> Void)? = nil, isSubmitting: Bool = false, submissionError: String? = nil) {
        self.records = records ?? .loaded(days)
        self.doctorName = doctorName; self.patientName = patientName
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
            AppHeader(title: "진료 전 기록", description: subtitle)
                .overlay(alignment: .topLeading) { PrevisitBackButton(label: "닫기", action: close) }
            ScrollView {
                VStack(spacing: 20) {
                    if step != .day { recordNotice }
                    switch step {
                    case .day: dayList
                    case .letter: letter
                    case .mood: moodList
                    }
                }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 40).padding(.bottom, 30)
            }.scrollDismissesKeyboard(.interactively)
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
                .background(AppColors.background)
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
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
    }
    private var subtitle: String {
        switch step {
        case .day: "선생님과 얘기 해보고 싶은 날이 있나요?"
        case .letter: "선생님과 어떤 이야기를 나눠보고 싶나요?"
        case .mood: "진료를 앞두고, 지금 어떤 기분인가요?"
        }
    }
    @ViewBuilder private var dayList: some View {
        switch records {
        case .loading, .failed: recordNotice
        case .loaded(let days):
            if days.isEmpty {
                Text("아직 저장한 기록이 없어요. 통증이나 증상을 기록한 뒤 다시 열어 주세요.")
                    .appTextStyle(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("previsit.empty")
            }
            LazyVStack(spacing: 16) {
            ForEach(days) { day in
                Button { session.selectDay(day) } label: {
                    PrevisitDayCard(day: day, selected: draft.day?.id == day.id)
                }.buttonStyle(.plain).disabled(!day.isSelectable)
                    .accessibilityValue(draft.day?.id == day.id ? "선택됨" : "선택 안 됨")
                    .accessibilityIdentifier("previsit.day.\(day.id)")
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
        return VStack(spacing: 20) {
            if let day = draft.day { PrevisitDayCard(day: day) }
            VStack(alignment: .leading, spacing: 28) {
                Text("To \(doctorName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                ZStack(alignment: .topLeading) {
                    // 안내 문구는 입력칸을 누르면 바로 숨긴다 (플레이스홀더처럼)
                    if draft.letter.isEmpty && !writing {
                        Text("하고싶은말을 자유롭게 작성해주세요.")
                            .appTextStyle(.caption).foregroundStyle(AppColors.Previsit.placeholder)
                            .frame(maxWidth: .infinity).padding(.top, 38).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextEditor(text: Binding(
                        get: { session.draft.letter },
                        set: { session.draft.letter = String($0.prefix(200)) }
                    )).appFont(.body)
                        .multilineTextAlignment(.center).scrollContentBackground(.hidden).focused($writing)
                        .frame(minHeight: 156).accessibilityLabel("선생님께 전할 이야기")
                        .accessibilityIdentifier("previsit.letter")
                }
                Text("\(draft.letter.count)/200자").appTextStyle(.caption)
                    .foregroundStyle(draft.letter.count >= 200 ? AppColors.Feedback.error : AppColors.Semantic.Text.sub)
                Text("From. \(patientName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 40).frame(minHeight: 340)
                .appSurface(.previsitCard())
        }
    }
    private var moodList: some View {
        VStack(spacing: AppSpacing.item) {
            ForEach(StateOfMind.allCases, id: \.self) { mood in
                Button { session.draft.mood = mood } label: {
                    HStack(spacing: 20) {
                        PrevisitDoctorAvatar(mood: mood, size: 40)
                        VStack(alignment: .leading, spacing: AppSpacing.tight) {
                            if let caption = mood.caption {
                                Text(caption).appTextStyle(.caption).foregroundStyle(AppColors.Previsit.moodCaption)
                            }
                            Text(mood.title).appFont(.body).foregroundStyle(AppColors.Previsit.title)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(24).frame(minHeight: 96)
                        .appSurface(.previsitCard(selected: draft.mood == mood))
                }.buttonStyle(.plain).accessibilityValue(draft.mood == mood ? "선택됨" : "선택 안 됨")
                    .accessibilityIdentifier("previsit.mood.\(mood.rawValue)")
            }
        }
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
            HStack(spacing: 20) {
                if step != .day {
                    Button("이전") { session.previous() }
                        .buttonStyle(AppButtonStyle(kind: .back)).accessibilityIdentifier("previsit.previous")
                }
                Button(action: next) {
                    Text(step == .mood ? "전송하기" : "다음").frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.Previsit.nextIcon) }
                }.buttonStyle(AppButtonStyle()).disabled(!canContinue).accessibilityIdentifier("previsit.next")
            }
        }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 12).padding(.bottom, 2)
            .background(AppColors.background)
    }
    private var canContinue: Bool {
        guard !isSubmitting, draft.letter.count <= 200, session.canContinue else { return false }
        guard case .loaded(let days) = records else { return false }
        if step == .day {
            return days.contains { $0.id == draft.day?.id && $0.isSelectable }
        }
        return step != .mood || onSubmit != nil
    }
    private func next() {
        guard canContinue else { return }
        writing = false
        if step == .mood { showsSubmitConfirmation = true }
        else { session.next() }
    }
    private func close() { guard !isSubmitting else { return }; if let onClose { onClose() } else { dismiss() } }
}

struct PrevisitDayCard: View {
    let day: PrevisitDay
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(day.dateLabel).appTextStyle(.label).foregroundStyle(AppColors.Previsit.title)
                Text(day.weekday).appTextStyle(.caption).foregroundStyle(AppColors.Previsit.weekday)
            }
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                ForEach(Array((day.entries.isEmpty ? ["기록 없음"] : day.entries).enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: 4) {
                        Circle().fill(day.entries.isEmpty ? AppColors.Previsit.emptyDot : AppColors.Previsit.entryDot)
                            .frame(width: 7, height: 7).frame(width: 24, height: 24)
                        Text(entry).appTextStyle(.caption).foregroundStyle(AppColors.Previsit.entry)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            .frame(minHeight: day.entries.count > 1 ? 176 : 120, alignment: .topLeading)
            .appSurface(.previsitCard(selected: selected))
    }
}

struct PrevisitBackButton: View {
    var label = "뒤로"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.Previsit.backIcon).frame(width: 40, height: 40)
                .background(AppColors.Previsit.backSurface, in: Circle())
        }.accessibilityLabel(label).padding(.leading, 24).padding(.top, 5)
    }
}

struct PrevisitDoctorAvatar: View {
    var mood: StateOfMind = .candid
    var size: CGFloat = 40
    var body: some View {
        Circle().fill(color)
            .overlay(alignment: .top) {
                Image("PrevisitDoctorFace").resizable().scaledToFit()
                    .frame(width: size * 1.525, height: size * 1.525).offset(y: size * 0.075)
            }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
    var color: Color {
        switch mood {
        case .candid: AppColors.Previsit.Mood.candid
        case .comfortable: AppColors.Previsit.Mood.comfortable
        case .slowly: AppColors.Previsit.Mood.slowly
        case .carefully: AppColors.Previsit.Mood.carefully
        case .unsure: AppColors.Previsit.Mood.unsure
        }
    }
}
