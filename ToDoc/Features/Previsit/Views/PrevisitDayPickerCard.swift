import SwiftUI

struct PrevisitDayPickerCard: View {
    let day: PrevisitDay
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppColors.Semantic.Background.surface)
                        .overlay {
                            Circle().strokeBorder(selected ? AppColors.Semantic.Primary.default
                                                            : AppColors.Semantic.Border.default,
                                                  lineWidth: selected ? 7 : 1.5)
                        }
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    PrevisitDayHeading(day: day)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .disabled(!day.isSelectable)
            .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("previsit.day.\(day.id)")

            PrevisitDayDetails(day: day, showsDate: false, onSelect: onSelect)
        }
    }
}

/// 기록 선택과 별개로, 저장된 하루 내용을 원문 그대로 펼칩니다.
struct PrevisitDayDetails: View {
    let day: PrevisitDay
    let showsDate: Bool
    let allowsDisclosure: Bool
    let onSelect: (() -> Void)?
    @State private var isExpanded = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(day: PrevisitDay, showsDate: Bool = true, allowsDisclosure: Bool = true,
         onSelect: (() -> Void)? = nil) {
        self.day = day
        self.showsDate = showsDate
        self.allowsDisclosure = allowsDisclosure
        self.onSelect = onSelect
    }

    private var hasTypedRows: Bool { !day.painRows.isEmpty || !day.symptomRows.isEmpty }

    private var canExpand: Bool {
        guard allowsDisclosure else { return false }
        return day.painRows.count > 2 || day.symptomRows.count > 2 || (!hasTypedRows && day.entries.count > 2)
            || day.entries.contains { $0.count > 48 || $0.contains(where: \.isNewline) }
    }

    private var showsPreview: Bool { canExpand && !isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsDate { PrevisitDayHeading(day: day) }
            if allowsDisclosure {
                details
                    .padding(24)
                    .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
            } else {
                details
            }
        }
        .onChange(of: day.id) { _, _ in isExpanded = false }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let onSelect, day.isSelectable {
                Button(action: onSelect) {
                    recordRows
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AppActions.PressStyle())
                .accessibilityHint("이 날짜 선택")
            } else {
                recordRows
            }

            if canExpand {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "전문 접기" : "눌러서 전문 보기").appTypography(.label)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(AppActions.PressStyle())
                .accessibilityIdentifier("previsit.day.\(day.id).details")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var recordRows: some View {
        if day.entries.isEmpty {
            Text("기록 없음")
                .appTypography(.bodySmall)
                .foregroundStyle(AppColors.Semantic.Text.sub)
        } else if hasTypedRows {
            typedRows
        } else {
            ForEach(0..<visibleCount(day.entries.count), id: \.self) { index in
                rowText(day.entries[index])
            }
        }
    }

    @ViewBuilder private var typedRows: some View {
        if !day.painRows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("통증")
                ForEach(0..<visibleCount(day.painRows.count), id: \.self) { index in
                    painRow(day.painRows[index])
                }
            }
        }

        if !day.painRows.isEmpty, !day.symptomRows.isEmpty {
            AppColors.Semantic.Border.default.frame(height: 1).accessibilityHidden(true)
        }

        if !day.symptomRows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("증상")
                ForEach(0..<visibleCount(day.symptomRows.count), id: \.self) { index in
                    symptomRow(day.symptomRows[index])
                }
            }
        }
    }

    private func painRow(_ pain: PrevisitDay.PainRow) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 4) {
            layout {
                tag(pain.location.isEmpty ? "통증" : pain.location)
                Text(pain.after.map { "\(pain.before) → \($0)" } ?? "\(pain.before)점")
                    .appTypography(.labelLarge)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(pain.after.map { "복용 전 \(pain.before)점, 복용 후 \($0)점" }
                                        ?? "복용 전 \(pain.before)점")
            }
            if pain.after == nil { rowText("사후 통증 미기록") }
        }
    }

    private func symptomRow(_ symptom: PrevisitDay.SymptomRow) -> some View {
        let isInline = allowsDisclosure && !isExpanded && !dynamicTypeSize.isAccessibilitySize
        let layout = isInline
            ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        return layout {
            tag(symptom.label).layoutPriority(1)
            if let detail = symptom.detail { rowText(detail) }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appTypography(.labelLarge)
            .foregroundStyle(AppColors.Semantic.Text.default)
            .accessibilityAddTraits(.isHeader)
    }

    private func visibleCount(_ count: Int) -> Int { showsPreview ? min(2, count) : count }

    private func rowText(_ text: String) -> some View {
        Text(text)
            .appTypography(.bodySmall)
            .foregroundStyle(AppColors.Semantic.Text.default)
            .lineLimit(showsPreview ? 1 : nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func tag(_ title: String) -> some View {
        Text(title)
            .appTypography(.label)
            .foregroundStyle(AppColors.Semantic.Text.default)
            .lineLimit(showsPreview ? 1 : nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColors.Semantic.Chart.Category.Lime.light, in: Capsule())
    }
}

private struct PrevisitDayHeading: View {
    let day: PrevisitDay

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(day.displayDate)
                .appTypography(.labelLarge)
                .foregroundStyle(AppColors.Semantic.Text.default)
            Text(day.displayWeekday)
                .appTypography(.body)
                .foregroundStyle(AppColors.Semantic.Text.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
