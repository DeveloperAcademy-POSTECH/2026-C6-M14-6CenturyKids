import SwiftUI

/// 보낸 진료 전 기록 하나를 보여 줍니다. 보낸 날이 오늘이면 하고싶은말·기분을 고치거나 기록을 지울 수 있습니다.
/// 전송 완료 팝업에서 열면(onClose 있음) 왼쪽 위 버튼이 팝업으로 돌아가지 않고 진료 전 기록을 닫습니다.
struct PrevisitLetterView: View {
    let viewModel: PrevisitLetterViewModel
    let id: UUID
    var patientName = ""
    var onClose: (() -> Void)?
    @State private var editing: PrevisitEdit?
    @State private var showsDelete = false
    /// 지운 뒤 화면이 내려가는 동안 '찾을 수 없어요' 대신 마지막 내용을 보여 줍니다
    @State private var lastShown: PrevisitLetter?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let letter = viewModel.letter(id) ?? lastShown
        let canEdit = viewModel.letter(id).map(viewModel.canEdit) ?? false
        ScrollView {
            VStack(spacing: 16) {
                PrevisitSentHeader(date: letter.map(viewModel.sentDate), backLabel: onClose == nil ? "뒤로" : "닫기", onBack: close)
                if let letter {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionTitle("진료 전 기록")
                        writingCard(letter.draft.letter, canEdit: canEdit)
                        if let mood = letter.draft.mood { moodCard(mood, canEdit: canEdit) }
                    }
                    recordsSection(letter.draft.day).padding(.top, 10)
                    if canEdit { deleteLink.padding(.top, 10) }
                } else {
                    Text("진료 전 기록을 찾을 수 없어요.").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                        .accessibilityIdentifier("previsitLetter.missing")
                }
            }.padding(.horizontal, AppLayout.Phone.horizontalMargin).padding(.top, 4).padding(.bottom, 24)
        }
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .overlay(alignment: .bottom) { noticeToast }
        .overlay { if showsDelete { deleteDialog } }
        .sheet(item: $editing) { edit in
            switch edit {
            case .letter:
                PrevisitLetterEditSheet(text: letter?.draft.letter ?? "") { text in save(letter: text) }
                    .overlay(alignment: .bottom) { noticeToast }
            case .mood:
                PrevisitMoodEditSheet(selection: letter?.draft.mood ?? .unsure) { mood in save(mood: mood) }
                    .overlay(alignment: .bottom) { noticeToast }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: id) { await viewModel.loadDetail(id) }
        .onChange(of: viewModel.letter(id), initial: true) { _, current in if let current { lastShown = current } }
    }

    private func close() { if let onClose { onClose() } else { dismiss() } }

    /// 수정 실패는 시트가 열린 채로 알려야 해서 시트 위에도 같은 토스트를 겹칩니다.
    private var noticeToast: some View {
        ZStack {
            if let notice = viewModel.notice {
                AppFeedback.Toast(notice)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                    .onAppear { AccessibilityNotification.Announcement(notice).post() }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.notice)
    }

    private func save(letter text: String? = nil, mood: StateOfMind? = nil) {
        Task {
            if await viewModel.update(id, letter: text, mood: mood) { editing = nil }
        }
    }

    /// Figma Symptom Summary Card: 제목 · 연필 · 하고싶은말
    private func writingCard(_ message: String, canEdit: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("진료 전 기록")
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if canEdit { editButton("하고싶은말 수정") { editing = .letter } }
            }
            Text(message.isEmpty ? "남긴 말이 없어요" : message)
                .appTypography(.bodySmall)
                .foregroundStyle(message.isEmpty ? AppColors.Semantic.Text.placeholder
                                                  : AppColors.Semantic.Text.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
    }

    /// Figma Notification Card: 기분 아바타 · 기분 설명 · 기분 한마디 · 연필
    private func moodCard(_ mood: StateOfMind, canEdit: Bool) -> some View {
        AppCards.NotificationCard(mood.historyLabel, source: mood.caption ?? "", time: "", avatar: mood.avatar)
            .overlay(alignment: .topTrailing) {
                if canEdit { editButton("기분 수정") { editing = .mood }.padding(20) }
            }
    }

    private func editButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15))
                .foregroundStyle(AppColors.Semantic.Text.sub)
                .frame(width: 24, height: 24)
                .padding(10)
                .contentShape(Rectangle())
        }
        .padding(-10)
        .buttonStyle(AppActions.PressStyle())
        .accessibilityLabel(label)
    }

    private var deleteLink: some View {
        Button { showsDelete = true } label: {
            Text("기록 삭제하기")
                .appTypography(.caption)
                .underline()
                .foregroundStyle(AppColors.Semantic.Text.error)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(AppActions.PressStyle())
        .accessibilityIdentifier("previsitLetter.delete")
    }

    private var deleteDialog: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
            AppFeedback.Dialog("이 기록을 삭제할까요?", message: "의사 선생님 화면에서도 삭제돼요", style: .text,
                               primary: .init("그만두기") { showsDelete = false },
                               secondary: .init("삭제하기") {
                                   Task {
                                       guard await viewModel.delete(id) else { showsDelete = false; return }
                                       showsDelete = false
                                       close()
                                   }
                               },
                               secondaryKind: .destructive)
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .accessibilityAddTraits(.isModal)
        }
    }

    @ViewBuilder
    private func recordsSection(_ day: PrevisitDay?) -> some View {
        if viewModel.loadingDetails.contains(id) || viewModel.detailErrors[id] != nil || day != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("증상 기록")
                if viewModel.loadingDetails.contains(id) {
                    ProgressView("해당 날짜의 기록을 불러오고 있어요")
                } else if let error = viewModel.detailErrors[id] {
                    Text(error).appTypography(.bodySmall)
                    Button("다시 불러오기") { Task { await viewModel.loadDetail(id) } }
                } else if let day {
                    PrevisitDayDetails(day: day)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appTypography(.labelLarge)
            .foregroundStyle(AppColors.Semantic.Text.default)
            .accessibilityAddTraits(.isHeader)
    }
}
