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
        // 많은 순, 같으면 받은 순서(증상 순서). 이 순서가 배치와 색 순위가 됩니다.
        let ranked = symptoms.enumerated()
            .sorted { $0.element.weight != $1.element.weight ? $0.element.weight > $1.element.weight : $0.offset < $1.offset }
            .map(\.element)
        return RecordSymptomGridLayout {
            ForEach(Array(ranked.enumerated()), id: \.element.id) { rank, item in
                RecordSymptomBubble(item: item, color: RecordChartStyle.rankColor(rank))
                    .layoutValue(key: RecordSymptomWeight.self, value: item.weight)
            }
        }.frame(height: 280)
    }
}

private struct RecordSymptomBubble: View {
    let item: RecordSymptomItem
    let color: Color
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            // 모서리: min(짧은 변의 절반, 50)의 절반을 내림
            RoundedRectangle(cornerRadius: (min(side / 2, 50) / 2).rounded(.down)).fill(color)
                .overlay {
                    // 짧은 변의 절반(11~34pt)에서, 이름이 칸 너비에 들어가도록 더 줄입니다
                    let name = item.type.displayName
                    let fit = (proxy.size.width - 8) / CGFloat(max(name.count, 1))
                    Text(name).font(.system(size: max(min(min(max(side * 0.5, 11), 34), fit), 8), weight: .bold))
                        .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.3).padding(.horizontal, 4)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.type.displayName)
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

/// 받은 순서(많은 순)대로 놓습니다. 무게가 모두 같으면 '일' 줄 배치로 같은 크기,
/// 다르면 1위(동률이면 1위 전부, 위아래로 같은 높이)가 전체에서 차지하는 비율만큼 왼쪽을 채우고 나머지를 오른쪽에 비례해 놓습니다.
private struct RecordSymptomGridLayout: Layout {
    var spacing: CGFloat = 2
    /// 한 줄에 놓는 칸 수 (위 줄부터)
    static let dayRows: [Int: [Int]] = [1: [1], 2: [2], 3: [2, 1], 4: [2, 2], 5: [3, 2], 6: [3, 3], 7: [2, 2, 3], 8: [3, 3, 2]]
    static let rightRows: [Int: [Int]] = [1: [1], 2: [1, 1], 3: [1, 2], 4: [2, 2], 5: [1, 2, 2], 6: [2, 2, 2], 7: [1, 2, 2, 2]]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 345, height: 280))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let weights = subviews.map { max($0[RecordSymptomWeight.self], .leastNonzeroMagnitude) }
        guard let first = weights.first else { return }
        let top = weights.prefix { $0 == first }.count
        let place: (Int, CGRect) -> Void = { index, rect in
            let rect = rect.insetBy(dx: spacing / 2, dy: spacing / 2)
            subviews[index].place(at: rect.origin, proposal: ProposedViewSize(rect.size))
        }
        let all = Array(weights.indices)
        guard top < weights.count else {
            return rows(all, pattern: Self.dayRows[all.count] ?? [all.count], weights: weights, in: bounds, place)
        }
        let left = bounds.width * weights[..<top].reduce(0, +) / weights.reduce(0, +)
        let (leftRect, rightRect) = bounds.divided(atDistance: left, from: .minXEdge)
        rows(Array(all[..<top]), pattern: Array(repeating: 1, count: top), weights: weights, in: leftRect, place)
        let rest = Array(all[top...])
        rows(rest, pattern: Self.rightRows[rest.count] ?? [rest.count], weights: weights, in: rightRect, place)
    }
    /// 줄 높이는 그 줄 무게 합, 칸 너비는 줄 안의 무게 비율이라 칸 넓이가 무게에 비례합니다.
    private func rows(_ indices: [Int], pattern: [Int], weights: [Double], in rect: CGRect, _ place: (Int, CGRect) -> Void) {
        let total = indices.reduce(0) { $0 + weights[$1] }
        var start = 0, y = rect.minY
        for count in pattern where start < indices.count {
            let row = indices[start..<min(start + count, indices.count)]
            let rowSum = row.reduce(0) { $0 + weights[$1] }
            let height = rect.height * rowSum / total
            var x = rect.minX
            for index in row {
                let width = rect.width * weights[index] / rowSum
                place(index, CGRect(x: x, y: y, width: width, height: height))
                x += width
            }
            y += height; start += count
        }
    }
}

#Preview { NavigationStack { SymptomRecordDetailView() } }
