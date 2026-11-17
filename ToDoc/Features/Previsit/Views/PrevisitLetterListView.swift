import SwiftUI

/// 보낸 진료 전 기록을 달별로 묶어 최신순으로 보여 줍니다.
struct PrevisitLetterListView: View {
    let viewModel: PrevisitLetterViewModel
    var onSelect: (UUID) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PrevisitSentHeader(backLabel: "뒤로") { dismiss() }
                if viewModel.isLoading { ProgressView("기록을 불러오고 있어요") }
                if let error = viewModel.errorMessage {
                    Text(error).appTypography(.bodySmall)
                    Button("다시 불러오기") { Task { await viewModel.reload() } }
                }
                if !viewModel.isLoading && viewModel.errorMessage == nil && viewModel.letters.isEmpty {
                    emptyState
                }
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(viewModel.months) { month in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(month.id)
                                .appTypography(.labelLarge)
                                .foregroundStyle(AppColors.Semantic.Text.default)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(month.letters) { letter in
                                Button { onSelect(letter.id) } label: { row(letter) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("previsitLetters.\(letter.id)")
                            }
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

    private func row(_ letter: PrevisitLetter) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.sentDate(letter))
                        .appTypography(.labelLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                    if let mood = letter.draft.mood {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.Semantic.Primary.default)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text(mood.historyLabel)
                                .appTypography(.bodySmall)
                                .foregroundStyle(AppColors.Semantic.Text.default)
                        }
                    }
                }
                Text(viewModel.preview(letter))
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            AppCards.Chevron().accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
    }
}

/// 목록과 상세에서 같은 위치에 제목과 뒤로 버튼을 배치합니다.
struct PrevisitSentHeader: View {
    var date: String?
    let backLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            AppNavigation.PageTitle("진료 전 기록", alignment: .center)
            if let date {
                Text(date)
                    .appTypography(.label)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 31)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
        .overlay(alignment: .topLeading) {
            AppActions.IconButton(
                backLabel,
                icon: Image("DesignSystem/Components/Navigation/Prev"),
                fill: AppColors.Semantic.Background.secondary,
                action: onBack
            )
        }
    }
}

private extension StateOfMind {
    var historyLabel: String {
        switch self {
        case .candid: "안정돼요"
        case .comfortable: "긴장돼요"
        case .slowly: "걱정돼요"
        case .carefully: "불안해요"
        case .unsure: "잘 모르겠어요"
        }
    }
}
