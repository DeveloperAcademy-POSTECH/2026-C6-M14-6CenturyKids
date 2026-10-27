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
                if viewModel.letters.isEmpty {
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
                            Text(badge.text).appTypography(.caption)
                                .foregroundStyle(badge.isAlert ? AppColors.Semantic.Text.error : AppColors.Semantic.Text.sub)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(badge.isAlert ? Self.alertBadge : AppColors.Semantic.Background.secondary, in: Capsule())
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

    /// Figma badge/error (#FDD4CF). 디자인 시스템 색 목록에 아직 없어 여기 둡니다
    private static let alertBadge = Color(red: 253 / 255, green: 212 / 255, blue: 207 / 255)
}

#if DEBUG
#Preview("지난 기록 목록") {
    let viewModel = PrevisitLetterViewModel()
    var day = PrevisitSectionPreview.days[1]
    day.painBefore = 7; day.painAfter = 6; day.symptomCount = 2
    viewModel.send(.init(day: day, letter: "머리가 지끈거림", mood: .candid), to: "학로쌤")
    viewModel.send(.init(day: PrevisitSectionPreview.days[0], letter: "", mood: .slowly), to: "학로쌤")
    return NavigationStack { PrevisitLetterListView(viewModel: viewModel) }
}

#Preview("지난 기록 없음") {
    NavigationStack { PrevisitLetterListView(viewModel: PrevisitLetterViewModel()) }
}
#endif
