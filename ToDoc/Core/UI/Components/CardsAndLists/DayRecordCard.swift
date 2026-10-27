import SwiftUI

extension AppCards {
    /// 표시용 날짜·기록만 받으며 실제 저장 기록의 선택 상태는 화면이 관리합니다.
    struct DayRecordCard: View {
        private let day: String
        private let weekday: String
        private let records: [String]
        private let emptyText: String
        private let isSelected: Bool
        private let action: () -> Void

        init(
            day: String,
            weekday: String,
            records: [String],
            emptyText: String,
            isSelected: Bool = false,
            action: @escaping () -> Void
        ) {
            self.day = day
            self.weekday = weekday
            self.records = records
            self.emptyText = emptyText
            self.isSelected = isSelected
            self.action = action
        }

        @ViewBuilder
        var body: some View {
            if records.isEmpty {
                // 빈 날짜는 기록 선택 동작을 만들지 않으며 원본 색상을 그대로 표시합니다.
                content
            } else {
                SwiftUI.Button(action: action) { content }
                    .buttonStyle(AppActions.PressStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(day)
                        .appTypography(.labelLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                    Text(weekday)
                        .appTypography(.label)
                        .foregroundStyle(AppColors.Semantic.Text.disabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if records.isEmpty {
                        AppFeedback.StatusTag(emptyText, showsDot: false)
                    } else {
                        ForEach(records.indices, id: \.self) { index in
                            AppFeedback.StatusTag(records[index])
                        }
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(showsSelection ? AppColors.Semantic.Background.selected : AppColors.Semantic.Background.surface,
                        in: RoundedRectangle(cornerRadius: 30))
            .overlay {
                if showsSelection {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(AppColors.Semantic.Primary.default, lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .accessibilityElement(children: .combine)
        }

        private var showsSelection: Bool { isSelected && !records.isEmpty }
    }
}
