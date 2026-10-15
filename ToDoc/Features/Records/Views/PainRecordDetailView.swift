import SwiftUI

struct PainRecordDetailView: View {
    @State private var state: RecordDetailScreenState
    init(state: RecordDetailScreenState? = nil) { _state = State(initialValue: state ?? RecordDetailScreenState(kind: .pain)) }
    var body: some View {
        RecordDetailLayout(state: state) {
            if case .pain(let data) = state.content {
                RecordChartCard(caption: "진통제 복용 후", value: summary(data.averageDifference), range: state.rangeLabel) {
                    RecordPainChart(state: state, data: data)
                }
                if state.period == .day, data.records == nil { Text("시간별 통증 기록이 제공되지 않았어요.").foregroundStyle(.secondary) }
            }
        }
    }
    private func summary(_ value: Double?) -> String {
        guard let value else { return "변화량 미제공" }
        if value == 0 { return "평균 변화가 없어요" }
        return "평균 \(RecordDisplay.number(abs(value)))점 " + (value > 0 ? "낮아졌어요" : "높아졌어요")
    }
}

private struct RecordPainChart: View {
    let state: RecordDetailScreenState
    let data: RecordPainDetail
    var body: some View {
        VStack(spacing: 12) {
            RecordPlot { size in
                if state.period == .day {
                    ForEach(data.records ?? [], id: \.id) { record in
                        // 실제 기록 시각을 시간축에 표시합니다. 날짜만 주어진 집계를 임의 시각으로 만들지 않습니다.
                        let parts = state.calendar.dateComponents([.hour, .minute], from: record.recordedDate)
                        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
                        mark(before: Double(record.painBefore), after: Double(record.painAfter), size: size, width: 14)
                            .frame(width: 14, height: size.height).position(x: size.width * hour / 24, y: size.height/2)
                            .accessibilityLabel("\(parts.hour ?? 0)시 \(parts.minute ?? 0)분, 복용 전 \(record.painBefore)점, 복용 후 \(record.painAfter)점")
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(state.days, id: \.self) { date in
                            let day = data.days.first { state.calendar.isDate($0.date, inSameDayAs: date) }
                            Group {
                                if let day { mark(before: day.averageBefore, after: day.averageAfter, size: size, width: state.period == .week ? 20 : 5) }
                                else { Capsule().fill(Color(white: 0.85)).frame(width: state.period == .week ? 16 : 5, height: 5).frame(maxHeight: .infinity, alignment: .bottom) }
                            }.frame(maxWidth: .infinity)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(state.calendar.component(.day, from: date))일")
                                .accessibilityValue(day.map { "복용 전 \(RecordDisplay.number($0.averageBefore))점, 복용 후 \(RecordDisplay.number($0.averageAfter))점" } ?? "기록 없음")
                        }
                    }.frame(width: size.width, height: size.height)
                }
            }
            if state.period == .day {
                HStack(spacing: 0) {
                    ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                        Text("\(hour)").modifier(RecordTextStyle(size: 12)).fixedSize()
                        if hour < 24 { Spacer(minLength: 0) }
                    }
                }.padding(.leading, 20).foregroundStyle(.secondary).accessibilityHidden(true)
            } else { RecordDateAxis(state: state) }
        }
    }
    private func mark(before: Double, after: Double, size: CGSize, width: CGFloat) -> some View {
        let top = size.height * (1 - RecordDisplay.fraction(max(before, after), maximum: 10))
        let bottom = size.height * (1 - RecordDisplay.fraction(min(before, after), maximum: 10))
        return ZStack(alignment: .top) {
            Rectangle().fill(state.period == .week ? AnyShapeStyle(RecordChartStyle.pain) : AnyShapeStyle(RecordChartStyle.symptom))
                .frame(width: width, height: size.height)
                .mask(alignment: .top) { Capsule().frame(width: width, height: max(bottom-top, 3)).offset(y: top) }
            if state.period == .week {
                ForEach([before, after].indices, id: \.self) { index in
                    let y = size.height * (1 - RecordDisplay.fraction([before, after][index], maximum: 10)) - width/2
                    Circle().fill(.white).frame(width: width, height: width).offset(y: y)
                    Rectangle().fill(RecordChartStyle.pain).frame(width: width, height: size.height)
                        .mask(alignment: .top) { Circle().strokeBorder(lineWidth: 3).frame(width: width, height: width).offset(y: y) }
                }
            }
        }.frame(height: size.height, alignment: .top)
    }
}

#Preview { NavigationStack { PainRecordDetailView() } }
