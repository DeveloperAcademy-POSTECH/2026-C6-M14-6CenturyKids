import SwiftUI

/// Figma 417:19245·417:19189. 전달받은 기록 카드와 입력 화면을 표시합니다.
struct PrevisitRecordView: View {
    let days: [PrevisitDay]
    var doctorName = "선생님"
    var patientName = ""
    var onClose: (() -> Void)?
    var onSubmit: ((PrevisitDraft) -> Void)?
    @State private var step: PrevisitStep
    @State private var draft: PrevisitDraft
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    init(days: [PrevisitDay] = [], doctorName: String = "선생님", patientName: String = "",
         initialStep: PrevisitStep = .day, initialDraft: PrevisitDraft = .init(),
         onClose: (() -> Void)? = nil, onSubmit: ((PrevisitDraft) -> Void)? = nil) {
        self.days = days; self.doctorName = doctorName; self.patientName = patientName
        self.onClose = onClose; self.onSubmit = onSubmit
        _step = State(initialValue: initialStep); _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "진료 전 기록", description: subtitle)
                .overlay(alignment: .topLeading) {
                    Button(action: close) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.Previsit.backIcon).frame(width: 40, height: 40)
                            .background(AppColors.Previsit.backSurface, in: Circle())
                    }.accessibilityLabel("닫기").padding(.leading, 24).padding(.top, 5)
                }
            ScrollView {
                VStack(spacing: 20) {
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
    private var dayList: some View {
        LazyVStack(spacing: 16) {
            if days.isEmpty {
                Text("표시할 기록이 없어요.").appTextStyle(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
            ForEach(days) { day in
                Button { draft.day = day } label: {
                    PrevisitDayCard(day: day, selected: draft.day?.id == day.id)
                }.buttonStyle(.plain).disabled(day.entries.isEmpty)
                    .accessibilityValue(draft.day?.id == day.id ? "선택됨" : "선택 안 됨")
                    .accessibilityIdentifier("previsit.day.\(day.id)")
            }
        }
    }
    private var letter: some View {
        VStack(spacing: 20) {
            if let day = draft.day { PrevisitDayCard(day: day) }
            VStack(alignment: .leading, spacing: 28) {
                Text("To \(doctorName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                ZStack(alignment: .topLeading) {
                    if draft.letter.isEmpty {
                        Text("하고싶은말을 자유롭게 작성해주세요.")
                            .appTextStyle(.caption).foregroundStyle(AppColors.Previsit.placeholder)
                            .frame(maxWidth: .infinity).padding(.top, 38).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextEditor(text: $draft.letter).appFont(.body)
                        .multilineTextAlignment(.center).scrollContentBackground(.hidden).focused($writing)
                        .frame(minHeight: 156).accessibilityLabel("선생님께 전할 이야기")
                        .accessibilityIdentifier("previsit.letter")
                }
                Text("From. \(patientName)").appTextStyle(.label).foregroundStyle(AppColors.Previsit.letterSignature)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.vertical, 40).frame(minHeight: 340)
                .appSurface(.previsitCard())
        }
    }
    private var moodList: some View {
        VStack(spacing: AppSpacing.item) {
            ForEach(PrevisitMood.allCases) { mood in
                Button { draft.mood = mood } label: {
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
            if step == .mood, onSubmit == nil {
                Text("전송 기능을 준비 중이에요. 입력한 내용은 서버에 저장·전송되지 않아요.")
                    .appTextStyle(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("previsit.unsent")
            }
            HStack(spacing: 20) {
                if step != .day {
                    Button("이전") { step = step == .mood ? .letter : .day }
                        .buttonStyle(AppButtonStyle(kind: .back)).accessibilityIdentifier("previsit.previous")
                }
                Button(action: next) {
                    Text(step == .mood ? (onSubmit == nil ? "전송 준비 중" : "전송하기") : "다음").frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.Previsit.nextIcon) }
                }.buttonStyle(AppButtonStyle()).disabled(!canContinue).accessibilityIdentifier("previsit.next")
            }
        }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 12).padding(.bottom, 2)
            .background(AppColors.background)
    }
    private var canContinue: Bool {
        switch step {
        case .day: days.contains { $0.id == draft.day?.id && !$0.entries.isEmpty }
        case .letter: true
        case .mood: draft.mood != nil && onSubmit != nil
        }
    }
    private func next() {
        guard canContinue else { return }
        switch step {
        case .day: step = .letter
        case .letter: writing = false; step = .mood
        case .mood: onSubmit?(draft)
        }
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
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

struct PrevisitDoctorAvatar: View {
    var mood: PrevisitMood = .candid
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
