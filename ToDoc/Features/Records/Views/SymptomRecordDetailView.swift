import SwiftUI
import UIKit

/// 하루 기록: 위는 증상 그래프(넓이가 횟수에 비례하는 칸), 아래는 증상마다 세부 카드.
/// 기준은 Figma '하루 기록 · 통증 점수 — 개발 전달'의 하루 기록 부분입니다. 화면을 넘으면 스크롤합니다.
struct SymptomRecordDetailView: View {
    @State var state = RecordDetailScreenState(kind: .symptom)
    /// 펼친 증상 (기간을 바꾸면 모두 접힘)
    @State private var expanded: Set<SymptomType> = []
    var body: some View {
        RecordDetailLayout(state: state, editing: state.isEditing) {
            if case .symptom(let data) = state.content {
                if data.symptoms.isEmpty {
                    RecordSymptomEmptyBox(period: state.period)
                } else {
                    VStack(spacing: 24) {
                        RecordSymptomTreemapView(items: data.symptoms).frame(height: 240)
                        cards(data.symptoms)
                    }
                }
            }
        }
        .onChange(of: state.periodLabel) { expanded = [] }
        .onChange(of: state.period) { expanded = [] }
    }

    private func cards(_ items: [RecordSymptomItem]) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            if state.canEdit {
                // 수정: 보이는 카드 전체를 편집 상태로. 카드마다 완료·삭제하면 저장되고, 닫기는 남은 편집을 버립니다.
                HStack(spacing: 8) {
                    if state.isSaving { ProgressView().controlSize(.small) }
                    Button(state.isEditing ? "닫기" : "수정") { state.onAction?(state.isEditing ? .endEdit : .edit) }
                        .appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                        .buttonStyle(.plain).disabled(state.onAction == nil || state.isSaving)
                }
            }
            VStack(spacing: 10) {
                ForEach(items) { item in
                    let count = item.count.map { "\($0)회" }
                    let toggle = { expanded.formSymmetricDifference([item.type]) }
                    if item.cards.count > 1 && (state.isEditing || expanded.contains(item.type)) {
                        // 펼침: 제목 카드 한 장 + 기록 카드 최신순
                        RecordSymptomCard(type: item.type, quote: nil, trailing: count,
                                          expanded: state.isEditing ? nil : true, toggle: toggle)
                        ForEach(item.cards) { card in
                            if state.editingEntryIDs.contains(card.id) {
                                editor(card, item.type)
                            } else {
                                RecordSymptomEntryCard(date: state.period == .day ? nil : dateLabel(card.date), quote: card.quote)
                            }
                        }
                    } else if let card = item.cards.first {
                        // 접힘: 제목과 가장 최근 원문을 한 장에
                        if state.editingEntryIDs.contains(card.id) {
                            editor(card, item.type)
                        } else {
                            RecordSymptomCard(type: item.type, quote: card.quote, trailing: count,
                                              expanded: item.cards.count > 1 ? false : nil, toggle: toggle)
                        }
                    }
                }
            }
        }
    }

    private func editor(_ card: RecordSymptomCardItem, _ type: SymptomType) -> some View {
        SymptomSummaryEntryEditor(draft: card.entry, title: type.recordCardName, errorMessage: state.editErrors[card.id],
                                  onDelete: { state.onAction?(.delete(card.id)) },
                                  onFinish: { state.onAction?(.finishEdit(card.id, $0)) })
            .disabled(state.isSaving)
            .padding(20).background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func dateLabel(_ date: Date) -> String {
        "\(state.calendar.component(.month, from: date))월 \(state.calendar.component(.day, from: date))일"
    }
}

/// 펼친 증상의 기록 한 장: 주·월은 날짜, 아래 원문 두 줄
private struct RecordSymptomEntryCard: View {
    let date: String?
    let quote: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date { Text(date).appTypography(.caption).foregroundStyle(AppColors.Semantic.Text.sub) }
            Text(quote.map { "\"\($0)\"" } ?? "남긴 말이 없어요").appTypography(.bodySmall)
                .foregroundStyle(AppColors.Semantic.Text.sub).lineLimit(2)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

/// 세부 카드 한 장: 색 점 + 이름, 오른쪽 횟수와 접기 화살표, 아래 원문 두 줄 (펼친 제목 카드는 원문 없이)
private struct RecordSymptomCard: View {
    let type: SymptomType
    let quote: String?
    var trailing: String?
    /// nil이면 화살표 없음
    var expanded: Bool?
    var toggle: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let expanded {
                Button(action: toggle) { header(expanded) }.buttonStyle(.plain)
                    .accessibilityHint(expanded ? "접으면 가장 최근 기록만 보여요" : "펼치면 이 기간의 기록을 모두 보여요")
            } else {
                header(nil)
            }
            if let quote {
                Text("\"\(quote)\"").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func header(_ expanded: Bool?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(type.recordColors.dark).frame(width: 10, height: 10)
                Text(type.recordCardName).modifier(RecordTextStyle(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.Semantic.Text.default)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                if let trailing {
                    Text(trailing).modifier(RecordTextStyle(size: 15, weight: .regular)).foregroundStyle(AppColors.Semantic.Text.sub)
                }
                if let expanded {
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .rotationEffect(.degrees(expanded ? 180 : 0)).accessibilityHidden(true)
                }
            }
        }
        .frame(minHeight: 24).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(expanded.map { $0 ? "펼침" : "접힘" } ?? "")
    }
}

private struct RecordSymptomEmptyBox: View {
    let period: RecordPeriod
    var body: some View {
        VStack(spacing: 8) {
            Text(period == .day ? "이 날은 기록이 없어요" : period == .week ? "이 주에는 기록이 없어요" : "이 달에는 기록이 없어요")
                .modifier(RecordTextStyle(size: 18, weight: .bold)).foregroundStyle(AppColors.Semantic.Text.default)
            Text("증상을 기록하면 여기에 모여요").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).frame(height: 240)
        .background(AppColors.Semantic.Background.secondary, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

/// 증상 그래프: 칸 사이 간격 0, 모서리 24, 테두리 2 INSIDE 세로 그라데이션 (그림자 없음)
private struct RecordSymptomTreemapView: View {
    let items: [RecordSymptomItem]
    var body: some View {
        GeometryReader { proxy in
            let labels = items.map { RecordSymptomTreemap.Label(name: $0.type.recordChartName, count: $0.count.map { "\($0)회" }) }
            let cells = RecordSymptomTreemap.layout(weights: items.map(\.weight), labels: labels, in: proxy.size,
                                                    measure: RecordSymptomCellText.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(items, zip(labels, cells))), id: \.0.id) { item, pair in
                    RecordSymptomCell(type: item.type, label: pair.0, tier: pair.1.tier)
                        .frame(width: pair.1.rect.width, height: pair.1.rect.height)
                        .offset(x: pair.1.rect.minX, y: pair.1.rect.minY)
                }
            }
        }
    }
}

private struct RecordSymptomCell: View {
    let type: SymptomType
    let label: RecordSymptomTreemap.Label
    let tier: RecordSymptomTreemap.Tier
    var body: some View {
        let colors = type.recordColors
        let shape = RoundedRectangle(cornerRadius: 24)
        shape.fill(colors.fill)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [colors.borderTop, colors.borderBottom], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 2)
            }
            .overlay {
                VStack(spacing: RecordSymptomTreemap.countSpacing) {
                    switch tier {
                    case .e: text(label.inline, size: tier.nameSize, bold: true, lineHeight: tier.nameLineHeight)
                    case .f: text(label.name, size: tier.nameSize, bold: true, lineHeight: tier.nameLineHeight)
                    default:
                        text(label.name, size: tier.nameSize, bold: true, lineHeight: tier.nameLineHeight)
                        if let count = label.count, let size = tier.countSize {
                            text(count, size: size, bold: false, lineHeight: tier.countLineHeight)
                        }
                    }
                }
                .foregroundStyle(colors.text).padding(.horizontal, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([type.recordCardName, label.count].compactMap(\.self).joined(separator: " "))
    }

    private func text(_ string: String, size: CGFloat, bold: Bool, lineHeight: CGFloat) -> some View {
        Text(string).font(Font(RecordSymptomCellText.font(size, bold: bold))).tracking(RecordSymptomCellText.tracking(size))
            .lineLimit(1).frame(height: lineHeight)
    }
}

/// 칸 글자: Pretendard, 크기별 자간은 디자인 시스템 텍스트 사다리 값. 칸 크기가 정해져 있어 글자 크기 조절은 따르지 않습니다.
private enum RecordSymptomCellText {
    static func font(_ size: CGFloat, bold: Bool) -> UIFont {
        _ = AppTypography.registerFont
        let weight: AppTypography.Semantic.Weight = bold ? .bold : .regular
        return UIFont(name: weight.fontName, size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }
    static func tracking(_ size: CGFloat) -> CGFloat {
        let percent = AppTypography.Semantic.allCases.first { $0.specification.size == size }?.specification.letterSpacingPercent ?? 0
        return size * percent / 100
    }
    static func width(_ string: String, size: CGFloat, bold: Bool) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font(size, bold: bold), .kern: tracking(size)]).width.rounded(.up)
    }
}

/// 증상마다 고정 색 (그래프 칸·카드 색 점·주 탭 목록 모두 같음)
private struct RecordSymptomColors {
    let fill: Color, text: Color, dark: Color
    let borderTop: Color, borderBottom: Color
    init(fill: Color, text: Color, dark: Color) {
        self.fill = fill; self.text = text; self.dark = dark
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let border = RecordSymptomTreemap.border(of: (Double(red), Double(green), Double(blue)))
        let color = { (rgb: RecordSymptomTreemap.RGB) in Color(red: rgb.red, green: rgb.green, blue: rgb.blue) }
        borderTop = color(border.top); borderBottom = color(border.bottom)
    }
}

private extension SymptomType {
    var recordColors: RecordSymptomColors {
        typealias Category = AppColors.Semantic.Chart.Category
        return switch self {
        case .nauseaVomiting: RecordSymptomColors(fill: Category.Cyan.fill, text: Category.Cyan.text, dark: Category.Cyan.dark)
        case .diarrhea: RecordSymptomColors(fill: Category.Orange.fill, text: Category.Orange.text, dark: Category.Orange.dark)
        case .dehydrationNutrition: RecordSymptomColors(fill: Category.Lime.fill, text: Category.Lime.text, dark: Category.Lime.dark)
        case .rashItching: RecordSymptomColors(fill: Category.Purple.fill, text: Category.Purple.text, dark: Category.Purple.dark)
        case .numbness: RecordSymptomColors(fill: Category.Blue.fill, text: Category.Blue.text, dark: Category.Blue.dark)
        case .constipation: RecordSymptomColors(fill: Category.Yellow.fill, text: Category.Yellow.text, dark: Category.Yellow.dark)
        case .oralPain: RecordSymptomColors(fill: Category.Pink.fill, text: Category.Pink.text, dark: Category.Pink.dark)
        case .other: RecordSymptomColors(fill: Category.Gray.fill, text: Category.Gray.text, dark: Category.Gray.dark)
        }
    }
}

#Preview { NavigationStack { SymptomRecordDetailView() } }
