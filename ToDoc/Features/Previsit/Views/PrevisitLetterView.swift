import SwiftUI

/// Figma 03 기록 상세(758:1082). 보낸 진료 전 기록 하나를 보여 주고 수정·삭제로 보냅니다.
/// 전송 완료 팝업에서 열면(onClose 있음) 왼쪽 위 버튼이 팝업으로 돌아가지 않고 진료 전 기록을 닫습니다.
/// 삭제 뒤 이동은 ViewModel의 notice(.deleted)를 보고 부모가 정합니다.
struct PrevisitLetterView: View {
    let viewModel: PrevisitLetterViewModel
    let id: UUID
    var patientName = ""
    var onClose: (() -> Void)?
    @State private var showsEdit = false
    @State private var showsDelete = false
    /// 지운 뒤 화면이 내려가는 동안 '찾을 수 없어요' 대신 마지막 내용을 보여 줍니다
    @State private var lastShown: PrevisitLetter?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let letter = viewModel.letter(id) ?? lastShown
        ScrollView {
            VStack(spacing: 16) {
                PrevisitScreenHeader(overline: "지난 기록", title: "진료 전 기록", backLabel: onClose == nil ? "뒤로" : "닫기") {
                    if let onClose { onClose() } else { dismiss() }
                }
                if let letter {
                    if let day = letter.draft.day {
                        AppCards.DayRecordCard(day: viewModel.recordDayTitle(day), weekday: day.weekday,
                                               records: day.entries, emptyText: "기록 없음") {}
                            .previsitReadOnly()
                    }
                    if let mood = letter.draft.mood {
                        AppCards.MoodOption(mood.title, avatar: mood.avatar) {}.previsitReadOnly()
                    }
                    AppCards.NoteCard(to: "To. \(letter.doctorName)", from: patientName.isEmpty ? nil : "From. \(patientName)") {
                        Text(letter.draft.letter.isEmpty ? "남긴 말이 없어요" : letter.draft.letter)
                            .foregroundStyle(letter.draft.letter.isEmpty ? AppColors.Semantic.Text.placeholder
                                                                         : AppColors.Semantic.Text.default)
                    }
                } else {
                    Text("진료 전 기록을 찾을 수 없어요.").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                        .accessibilityIdentifier("previsitLetter.missing")
                }
            }.padding(.horizontal, AppLayout.Phone.horizontalMargin).padding(.top, 4).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if letter != nil { footer }
        }
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.letter(id), initial: true) { _, current in if let current { lastShown = current } }
        .overlay {
            if showsDelete {
                PrevisitConfirmDialog(title: "이 기록을 삭제할까요?", message: "선생님 화면에서도 사라지고, 다시 되돌릴 수 없어요.",
                                      destructiveTitle: "삭제하기", cancelTitle: "계속 수정하기",
                                      onDestructive: { showsDelete = false; viewModel.delete(id) },
                                      onCancel: { showsDelete = false })
            }
        }
        .navigationDestination(isPresented: $showsEdit) {
            PrevisitLetterEditView(viewModel: viewModel, id: id)
        }
    }

    private var footer: some View {
        AppActions.BottomAction(primary: .init("수정하기") { viewModel.beginEdit(id); showsEdit = true },
                                secondary: .init("삭제하기") { showsDelete = true })
            .padding(.top, 12).padding(.bottom, 2)
            .background(AppColors.Semantic.Background.default)
            .overlay(alignment: .top) {
                // Figma 05: 저장한 뒤 상세로 돌아오면 버튼 위에 잠깐 띄웁니다
                if viewModel.notice == .saved {
                    PrevisitToast(message: PrevisitLetterViewModel.Notice.saved.message)
                        .offset(y: -56)
                }
            }
    }
}

/// Figma 04 기록 수정(782:933). 하고싶은말·기분만 고칩니다. 고친 게 있을 때 뒤로 가면 그만둘지 묻습니다(04-1).
struct PrevisitLetterEditView: View {
    @Bindable var viewModel: PrevisitLetterViewModel
    let id: UUID
    @State private var choosesMood = false
    @State private var showsDiscard = false
    @FocusState private var writing: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let letter = viewModel.letter(id)
        ScrollView {
            VStack(spacing: 16) {
                PrevisitScreenHeader(overline: letter.map(viewModel.sentDate) ?? "", title: "기록 수정", backLabel: "뒤로", onBack: back)
                if let day = letter?.draft.day {
                    AppCards.DayRecordCard(day: viewModel.recordDayTitle(day), weekday: day.weekday,
                                           records: day.entries, emptyText: "기록 없음") {}
                        .previsitReadOnly().opacity(0.5).accessibilityHint("고를 수 없어요")
                }
                moods
                // 공용 Text Area는 배경이 아직 background/default라, 시안대로 흰 바탕인 입력칸을 직접 둡니다
                ZStack(alignment: .topLeading) {
                    if viewModel.editingLetter.isEmpty && !writing {
                        Text("하고싶은말을 자유롭게 작성해주세요.").appTypography(.body)
                            .foregroundStyle(AppColors.Semantic.Text.placeholder)
                            .padding(.horizontal, 5).padding(.vertical, 8).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextEditor(text: $viewModel.editingLetter).appTypography(.body)
                        .foregroundStyle(AppColors.Semantic.Text.default).scrollContentBackground(.hidden)
                        .focused($writing).accessibilityLabel("선생님께 전할 이야기")
                        .accessibilityIdentifier("previsitLetterEdit.letter")
                }
                .padding(32 - 5).frame(height: 230)
                .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 40))
            }.padding(.horizontal, AppLayout.Phone.horizontalMargin).padding(.top, 4).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true) // 밀어서 뒤로 가면 그만둘지 묻지 못한다
        .onAppear { if viewModel.editingID != id { viewModel.beginEdit(id) } }
        .overlay {
            if showsDiscard {
                PrevisitConfirmDialog(title: "수정을 그만둘까요?", message: "지금까지 고친 내용은 저장되지 않아요",
                                      destructiveTitle: "그만두기", cancelTitle: "계속 수정하기",
                                      onDestructive: { showsDiscard = false; viewModel.cancelEdit(); dismiss() },
                                      onCancel: { showsDiscard = false })
            }
        }
    }

    /// 고른 기분 카드를 누르면 다섯 가지를 펼쳐 다시 고릅니다
    @ViewBuilder private var moods: some View {
        if choosesMood {
            ForEach(PrevisitMood.allCases) { mood in
                AppCards.MoodOption(mood.title, avatar: mood.avatar, isSelected: viewModel.editingMood == mood) {
                    viewModel.editingMood = mood
                    choosesMood = false
                }.accessibilityIdentifier("previsitLetterEdit.mood.\(mood.rawValue)")
            }
        } else if let mood = viewModel.editingMood {
            AppCards.MoodOption(mood.title, avatar: mood.avatar, isSelected: true) {
                writing = false
                choosesMood = true
            }
            .overlay(alignment: .trailing) { AppCards.Chevron().padding(.trailing, 24).allowsHitTesting(false) }
            .accessibilityHint("눌러서 기분을 바꿀 수 있어요").accessibilityIdentifier("previsitLetterEdit.mood")
        }
    }

    @ViewBuilder private var footer: some View {
        if writing {
            AppActions.TextButton("입력 완료") { writing = false }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(AppColors.Semantic.Background.default)
                .accessibilityIdentifier("previsitLetterEdit.finishWriting")
        } else {
            AppActions.BottomAction(primary: .init("저장하기", isEnabled: viewModel.hasEditChanges) {
                viewModel.saveEdit()
                dismiss()
            })
            .padding(.top, 12).padding(.bottom, 2)
            .background(AppColors.Semantic.Background.default)
            .accessibilityIdentifier("previsitLetterEdit.save")
        }
    }

    private func back() {
        writing = false
        if viewModel.hasEditChanges { showsDiscard = true } else { viewModel.cancelEdit(); dismiss() }
    }
}

#if DEBUG
#Preview("기록 상세") {
    let viewModel = PrevisitLetterViewModel()
    viewModel.send(.init(day: PrevisitSectionPreview.days[1], letter: PrevisitSectionPreview.sampleLetter, mood: .candid), to: "학로쌤")
    return NavigationStack { PrevisitLetterView(viewModel: viewModel, id: viewModel.latest!.id, patientName: "조디") }
}

#Preview("기록 수정") {
    let viewModel = PrevisitLetterViewModel()
    viewModel.send(.init(day: PrevisitSectionPreview.days[1], letter: PrevisitSectionPreview.sampleLetter, mood: .candid), to: "학로쌤")
    return NavigationStack { PrevisitLetterEditView(viewModel: viewModel, id: viewModel.latest!.id) }
}
#endif
