import SwiftUI

struct PainRecordDetailView: View {
    @State private var state: RecordDetailScreenState
    init(state: RecordDetailScreenState? = nil) { _state = State(initialValue: state ?? RecordDetailScreenState(kind: .pain)) }
    var body: some View {
        RecordDetailLayout(state: state) {
            if case .pain(let data) = state.content {
                RecordChartCard(caption: caption, value: summary(data.averageDifference), difference: data.averageDifference,
                                range: state.period == .day ? "" : state.rangeLabel) {
                    RecordPainChart(state: state, data: data)
                }
                if state.period == .day, data.records == nil { Text("시간별 통증 기록이 제공되지 않았어요.").foregroundStyle(.secondary) }
            }
        }
    }
    private var caption: String {
        switch state.period { case .month: "이번 달 진통제 복용 후"; case .week: "이번 주 진통제 복용 후"; case .day: "하루 진통제 복용 후" }
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
    private var width: CGFloat { switch state.period { case .month: 4; case .week: 18; case .day: 12 } }
    var body: some View {
        VStack(spacing: 12) {
            RecordPlot { size in
                if state.period == .day {
                    ForEach(0...24, id: \.self) { hour in
                        Rectangle().fill(RecordChartStyle.green).frame(width: 1, height: 6)
                            .position(x: size.width * CGFloat(hour) / 24, y: size.height)
                    }.accessibilityHidden(true)
                    ForEach(data.records ?? [], id: \.id) { record in
                        // 실제 기록 시각을 시간축에 표시합니다. 날짜만 주어진 집계를 임의 시각으로 만들지 않습니다.
                        let parts = state.calendar.dateComponents([.hour, .minute], from: record.recordedDate)
                        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
                        mark(before: Double(record.painBefore), after: Double(record.painAfter), size: size)
                            .frame(width: width, height: size.height).position(x: size.width * hour / 24, y: size.height/2)
                            .accessibilityLabel("\(parts.hour ?? 0)시 \(parts.minute ?? 0)분, 복용 전 \(record.painBefore)점, 복용 후 \(record.painAfter)점")
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(state.days, id: \.self) { date in
                            let day = data.days.first { state.calendar.isDate($0.date, inSameDayAs: date) }
                            Group {
                                if let day { mark(before: day.averageBefore, after: day.averageAfter, size: size) }
                                else { Capsule().fill(Color(white: 0.85)).frame(width: state.period == .week ? 16 : 4, height: 4).padding(.bottom, 10).frame(maxHeight: .infinity, alignment: .bottom) }
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
                    ForEach([0, 12, 24], id: \.self) { hour in
                        Text("\(hour)").modifier(RecordTextStyle(size: 12)).fixedSize()
                        if hour < 24 { Spacer(minLength: 0) }
                    }
                }.padding(.leading, 20).foregroundStyle(.secondary).accessibilityHidden(true)
            } else { RecordDateAxis(state: state) }
        }
    }
    /// 복용 전·후 점수 사이를 막대로 그립니다. 주간은 점수 위치에 따라 색이 바뀌고, 낮은 점수 아래로 바탕 막대를 깝니다.
    private func mark(before: Double, after: Double, size: CGSize) -> some View {
        let top = size.height * (1 - RecordDisplay.fraction(max(before, after), maximum: 10))
        let bottom = size.height * (1 - RecordDisplay.fraction(min(before, after), maximum: 10))
        return ZStack(alignment: .top) {
            if state.period == .week {
                Capsule().fill(RecordChartStyle.track).frame(width: width, height: size.height - bottom + width/2).offset(y: bottom - width/2)
                // 10점·0점의 원이 잘리지 않도록 색 막대를 원 반지름만큼 위아래로 늘립니다.
                painFill(size) { Capsule().frame(width: width, height: bottom - top + width).offset(y: top) }
                ForEach([top, bottom].indices, id: \.self) { index in
                    let y = [top, bottom][index]
                    Circle().fill(.white).frame(width: width, height: width).offset(y: y - width/2)
                    painFill(size) { Circle().strokeBorder(lineWidth: 3).frame(width: width, height: width).offset(y: y) }
                }
            } else {
                Capsule().fill(RecordChartStyle.green).frame(width: width, height: max(bottom-top, width)).offset(y: top)
            }
        }.frame(height: size.height, alignment: .top)
    }
    /// mask는 원 반지름만큼 늘린 막대 기준 좌표입니다 (점수 위치 y는 그대로 쓰면 됩니다).
    private func painFill(_ size: CGSize, @ViewBuilder mask: () -> some View) -> some View {
        Rectangle().fill(RecordChartStyle.pain).frame(width: width, height: size.height + width)
            .mask(alignment: .top, mask).offset(y: -width/2)
    }
}

#Preview { NavigationStack { PainRecordDetailView() } }
