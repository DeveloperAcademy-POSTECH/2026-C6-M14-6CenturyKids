import SwiftUI

/// 보낸 진료 전 기록 하나를 읽기 전용으로 보여 줍니다.
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
                PrevisitSentHeader(date: letter.map(viewModel.sentDate), backLabel: onClose == nil ? "뒤로" : "닫기") {
                    if let onClose { onClose() } else { dismiss() }
                }
                if let letter {
                    writingSection(letter.draft.letter)
                    if let mood = letter.draft.mood {
                        AppCards.MoodOption(mood.title, sub: mood.caption, avatar: mood.avatar) {}
                            .previsitReadOnly()
                    }
                    recordsSection(letter.draft.day)
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

    private func writingSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("진료 전 기록")
            VStack(alignment: .leading, spacing: 12) {
                Text("진료 전 기록")
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
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
    }

    @ViewBuilder
    private func recordsSection(_ day: PrevisitDay?) -> some View {
        if viewModel.loadingDetails.contains(id) || viewModel.detailErrors[id] != nil || day != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("통증·증상 기록")
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
            .padding(.top, 8)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appTypography(.labelLarge)
            .foregroundStyle(AppColors.Semantic.Text.default)
            .accessibilityAddTraits(.isHeader)
    }
}
