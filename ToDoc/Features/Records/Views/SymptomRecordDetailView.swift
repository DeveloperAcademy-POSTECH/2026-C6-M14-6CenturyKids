import SwiftUI

struct SymptomRecordDetailView: View {
    @State var state = RecordDetailScreenState(kind: .symptom)
    var body: some View {
        RecordDetailLayout(state: state) {
            if case .symptom(let data) = state.content {
                RecordChartCard(caption: "증상 기록 · 있음으로 답한 항목",
                    value: data.presentCount.map { "\($0)건" } ?? "집계 미제공", range: state.rangeLabel) {
                    RecordSymptomChart(state: state, days: data.days)
                }
                if state.period == .day {
                    if let record = data.days.first?.record, !record.symptoms.isEmpty { entries(record) }
                    else { Text("기록된 답변이 없어요.").foregroundStyle(.secondary) }
                }
            }
        }
    }

    @ViewBuilder private func entries(_ record: SymptomRecordDisplay) -> some View {
        ForEach(SymptomPresence.allCases, id: \.self) { presence in
            let entries = record.entries(with: presence)
            if !entries.isEmpty {
                Text("\(presence.displayName)으로 답한 항목").font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.symptomType.displayName).modifier(RecordTextStyle(size: 16, weight: .semibold))
                    Text("증상 유무: \(entry.presence.displayName)").modifier(RecordTextStyle(size: 14, weight: .semibold))
                    if let location = entry.rawLocationText, !location.isEmpty {
                        Text(location).modifier(RecordTextStyle(size: 14))
                    } else if let part = entry.bodyPart {
                        Text([entry.bodySide?.displayName, part.displayName].compactMap { $0 }.joined(separator: " "))
                            .modifier(RecordTextStyle(size: 14))
                    }
                    if let detail = entry.detail, !detail.isEmpty { Text(detail).modifier(RecordTextStyle(size: 14)) }
                    if let count = entry.occurrenceCount { Text("횟수 \(count)회").modifier(RecordTextStyle(size: 14)).foregroundStyle(.secondary) }
                    if let minutes = entry.durationMinutes { Text("지속 시간 \(minutes)분").modifier(RecordTextStyle(size: 14)).foregroundStyle(.secondary) }
                }.fixedSize(horizontal: false, vertical: true)
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
            }
        }
    }
}

private struct RecordSymptomChart: View {
    let state: RecordDetailScreenState
    let days: [RecordSymptomDay]
    // 표시용 축 범위만 정합니다. 기간 합계와 일별 건수는 ViewModel이 제공합니다.
    private var maximum: Double { Double(max(days.compactMap(\.presentCount).max() ?? 0, 1)) }
    var body: some View {
        VStack(spacing: 12) {
            RecordPlot(scoreAxis: false) { size in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(state.days, id: \.self) { date in
                        let day = days.first { state.calendar.isDate($0.date, inSameDayAs: date) }
                        let count = day?.presentCount
                        let width: CGFloat = state.period == .day ? 60 : state.period == .week ? 20 : 5
                        let height = (size.height - 24) * RecordDisplay.fraction(count.map(Double.init), maximum: maximum)
                        VStack(spacing: 6) {
                            if let count {
                                if state.period != .month { Text("\(count)건").modifier(RecordTextStyle(size: 14)).fixedSize() }
                                if count == 0 {
                                    Circle().strokeBorder(RecordDisplay.green, lineWidth: 2).frame(width: 7, height: 7)
                                } else {
                                    UnevenRoundedRectangle(topLeadingRadius: width/2, topTrailingRadius: width/2)
                                        .fill(RecordChartStyle.symptom).frame(width: width, height: max(height, 1))
                                }
                            } else { Capsule().fill(Color(white: 0.85)).frame(width: width, height: 5) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(state.calendar.component(.month, from: date))월 \(state.calendar.component(.day, from: date))일")
                            .accessibilityValue(count.map { "증상 기록 \($0)건" } ?? (day == nil ? "기록 없음" : "집계 미제공"))
                    }
                }.frame(width: size.width, height: size.height)
            }
            RecordDateAxis(state: state)
            Text("있음으로 답한 항목 수 · 빈 원은 0건, 회색 표시는 기록 또는 집계 미제공")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview { NavigationStack { SymptomRecordDetailView() } }
