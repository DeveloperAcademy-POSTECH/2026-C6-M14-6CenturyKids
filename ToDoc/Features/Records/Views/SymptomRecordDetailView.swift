import SwiftUI

struct SymptomRecordDetailView: View {
    @State var state = RecordDetailScreenState(kind: .symptom)
    var body: some View {
        RecordDetailLayout(state: state) {
            if case .symptom(let data) = state.content {
                let entries = data.records.flatMap(\.presentSymptoms)
                if data.symptoms.isEmpty || entries.isEmpty {
                    Text("표시할 증상 기록이 없어요.").foregroundStyle(.secondary).padding(.vertical, 40)
                } else {
                    bubbles(data.symptoms).padding(.top, 20)
                    VStack(alignment: .trailing, spacing: 12) {
                        Button("수정") { state.onAction?(.edit) }
                            .modifier(RecordTextStyle(size: 14)).foregroundStyle(Color(white: 141/255))
                            .buttonStyle(.plain).disabled(state.onAction == nil)
                        ForEach(entries) { RecordSymptomCard(entry: $0) }
                    }.padding(.top, 20)
                }
            }
        }
    }

    private func bubbles(_ symptoms: [RecordSymptomItem]) -> some View {
        // 가장 큰 항목 위에만 말풍선을 띄웁니다 (일별은 표시하지 않음).
        let top = state.period == .day ? nil : symptoms.max { $0.weight < $1.weight }
        return RecordSymptomBubbleLayout {
            ForEach(symptoms) { item in
                RecordSymptomBubble(item: item, showsLabel: item.id == top?.id)
                    .layoutValue(key: RecordSymptomWeight.self, value: item.weight)
            }
        }.frame(height: 280)
    }
}

private struct RecordSymptomBubble: View {
    let item: RecordSymptomItem
    let showsLabel: Bool
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            RoundedRectangle(cornerRadius: min(side / 2, 50)).fill(RecordChartStyle.color(for: item.type))
                .overlay {
                    Text(item.type.displayName).font(.system(size: min(max(side * 0.5, 11), 34), weight: .bold))
                        .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.3).padding(.horizontal, 6)
                }
                .overlay(alignment: .top) {
                    if showsLabel, let label = item.label { RecordSymptomTooltip(text: label).offset(y: -18) }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.type.displayName).accessibilityValue(item.label ?? "")
    }
}

private struct RecordSymptomTooltip: View {
    let text: String
    var body: some View {
        VStack(spacing: 0) {
            Text(text).modifier(RecordTextStyle(size: 11)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color(white: 60/255), in: Capsule())
            Triangle().fill(Color(white: 60/255)).frame(width: 8, height: 5)
        }
    }
    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: rect.maxX, y: 0)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); $0.closeSubpath() }
        }
    }
}

private struct RecordSymptomCard: View {
    let entry: SymptomEntryDisplay
    private var title: String {
        let location = entry.rawLocationText.flatMap { $0.isEmpty ? nil : $0 }
            ?? entry.bodyPart.map { [entry.bodySide?.displayName, $0.displayName].compactMap { $0 }.joined(separator: " ") }
        return [entry.symptomType.displayName, location].compactMap { $0 }.joined(separator: " · ")
    }
    private var amount: String? {
        entry.occurrenceCount.map { "\($0)회" } ?? entry.durationMinutes.map { "\($0)분" }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).modifier(RecordTextStyle(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                if let amount {
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 232/255, green: 85/255, blue: 62/255)).frame(width: 6, height: 6)
                        Text(amount).modifier(RecordTextStyle(size: 12))
                    }
                }
            }
            if let detail = entry.detail, !detail.isEmpty { Text("'\(detail)'").modifier(RecordTextStyle(size: 12)) }
        }.fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22).padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .accessibilityElement(children: .combine)
    }
}

private struct RecordSymptomWeight: LayoutValueKey { static let defaultValue: Double = 1 }

/// 큰 항목부터 무게가 반씩 되도록 나누고, 긴 변을 따라 자릅니다. 크기 계산(무게)은 ViewModel이 제공합니다.
private struct RecordSymptomBubbleLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 345, height: 280))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let weights = subviews.map { max($0[RecordSymptomWeight.self], 0) }
        let order = subviews.indices.sorted { weights[$0] != weights[$1] ? weights[$0] > weights[$1] : $0 < $1 }
        place(order, weights: weights, in: bounds) { index, rect in
            let rect = rect.insetBy(dx: spacing / 2, dy: spacing / 2)
            subviews[index].place(at: rect.origin, proposal: ProposedViewSize(rect.size))
        }
    }
    private func place(_ order: [Int], weights: [Double], in rect: CGRect, _ assign: (Int, CGRect) -> Void) {
        guard order.count > 1 else { if let index = order.first { assign(index, rect) }; return }
        let total = order.reduce(0) { $0 + weights[$1] }
        // 앞쪽 합이 절반에 가장 가까운 지점에서 나눕니다. 무게가 모두 0이면 개수로 나눕니다.
        var split = 1, prefix = 0.0, best = Double.infinity
        for count in 1..<order.count {
            prefix += weights[order[count - 1]]
            let gap = total > 0 ? abs(prefix - total / 2) : abs(Double(count) - Double(order.count) / 2)
            if gap < best { best = gap; split = count }
        }
        let head = order[..<split].reduce(0) { $0 + weights[$1] }
        let ratio = total > 0 ? head / total : Double(split) / Double(order.count)
        let (first, second) = rect.width >= rect.height
            ? rect.divided(atDistance: rect.width * ratio, from: .minXEdge)
            : rect.divided(atDistance: rect.height * ratio, from: .minYEdge)
        place(Array(order[..<split]), weights: weights, in: first, assign)
        place(Array(order[split...]), weights: weights, in: second, assign)
    }
}

#Preview { NavigationStack { SymptomRecordDetailView() } }
