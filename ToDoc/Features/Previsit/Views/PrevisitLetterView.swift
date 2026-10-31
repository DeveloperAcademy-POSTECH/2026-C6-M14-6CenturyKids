import SwiftUI

/// Figma 03 기록 상세(758:1082). 보낸 진료 전 기록 하나를 읽기 전용으로 보여 줍니다.
/// 전송 완료 팝업에서 열면(onClose 있음) 왼쪽 위 버튼이 팝업으로 돌아가지 않고 진료 전 기록을 닫습니다.
struct PrevisitLetterView: View {
    let viewModel: PrevisitLetterViewModel
    let id: UUID
    var patientName = ""
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let letter = viewModel.letter(id)
        ScrollView {
            VStack(spacing: 16) {
                PrevisitScreenHeader(overline: "지난 기록", title: "진료 전 기록", backLabel: onClose == nil ? "뒤로" : "닫기") {
                    if let onClose { onClose() } else { dismiss() }
                }
                if let letter {
                    if viewModel.loadingDetails.contains(id) {
                        ProgressView("해당 날짜의 기록을 불러오고 있어요")
                    } else if let error = viewModel.detailErrors[id] {
                        Text(error).appTypography(.bodySmall)
                        Button("다시 불러오기") { Task { await viewModel.loadDetail(id) } }
                    } else if let day = letter.draft.day {
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
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: id) { await viewModel.loadDetail(id) }
    }
}
