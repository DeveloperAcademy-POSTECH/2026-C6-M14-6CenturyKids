import SwiftUI

/// Figma 02-A 전체 기록(782:1293, 빈 화면 782:1514). 보낸 달마다 묶어 최신순으로 보여 줍니다.
struct PrevisitLetterListView: View {
    let viewModel: PrevisitLetterViewModel
    var onSelect: (UUID) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PrevisitScreenHeader(overline: "지난 기록", title: "진료 전 기록", backLabel: "뒤로") { dismiss() }
                if viewModel.isLoading { ProgressView("기록을 불러오고 있어요") }
                if let error = viewModel.errorMessage {
                    Text(error).appTypography(.bodySmall)
                    Button("다시 불러오기") { Task { await viewModel.reload() } }
                }
                if !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.letters.isEmpty {
                    emptyState
                }
                ForEach(viewModel.months) { month in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(month.id).appTypography(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(month.letters) { letter in
                            Button { onSelect(letter.id) } label: { row(letter) }
                                .buttonStyle(.plain).accessibilityIdentifier("previsitLetters.\(letter.id)")
                        }
                    }
                }
            }.padding(.horizontal, AppLayout.Phone.horizontalMargin).padding(.top, 4).padding(.bottom, 24)
        }
        .background(AppColors.Semantic.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("아직 남긴 기록이 없어요").appTypography(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
            Text("진료 전에 선생님께 하고 싶은 말을 남겨보세요").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 32)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
            .accessibilityElement(children: .combine).accessibilityIdentifier("previsitLetters.empty")
    }

    /// Figma Record List Item: 기분 아바타 + 날짜 + 첫 줄 + 배지 + ›
    private func row(_ letter: PrevisitLetter) -> some View {
        HStack(spacing: 16) {
            (letter.draft.mood ?? .unsure).avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.sentDate(letter)).appTypography(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
                Text(viewModel.preview(letter)).appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                    .lineLimit(1).truncationMode(.tail)
                let badges = viewModel.badges(letter)
                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge).appTypography(.caption)
                                .foregroundStyle(AppColors.Semantic.Text.sub)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(AppColors.Semantic.Background.secondary, in: Capsule())
                        }
                    }.padding(.top, 8)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            AppCards.Chevron()
        }
        .padding(.leading, 20).padding(.trailing, 16).padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 124)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
    }
}
