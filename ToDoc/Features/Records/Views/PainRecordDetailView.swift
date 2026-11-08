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
    /// 일별: 한 화면에 나란히 놓는 기록 수. 더 많으면 옆으로 밀어 봅니다
    private static let visibleRecords = 6
    private static let timeGap: CGFloat = 12
    @ScaledMetric private var timeHeight: CGFloat = 18
    private var width: CGFloat { state.period == .month ? 4 : 20 }
    private var usesRings: Bool { state.period != .month }
    var body: some View {
        VStack(spacing: 12) {
            RecordPlot { size in
                if state.period == .day {
                    dayRecords(size)
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
                                .accessibilityValue(day.map { painDescription(before: $0.averageBefore, after: $0.averageAfter) } ?? "기록 없음")
                        }
                    }.frame(width: size.width, height: size.height)
                }
            }
            // 일별 기록 시각은 막대 아래(그래프 밖)에 그려서 그 자리를 비워 둡니다
            .padding(.bottom, state.period == .day ? Self.timeGap + timeHeight : 0)
            if state.period != .day { RecordDateAxis(state: state) }
        }
    }
    /// 일별: 기록 시각 위치가 아니라 기록 순서대로 나란히 놓고, 막대 아래에 기록 시각을 씁니다
    /// (비슷한 시각에 여러 번 기록해도 겹치지 않게). 기록이 하나면 가운데, 6개를 넘으면 옆으로 밀어 봅니다
    private func dayRecords(_ size: CGSize) -> some View {
        let records = data.records ?? []
        let column = size.width / CGFloat(min(max(records.count, 1), Self.visibleRecords))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(records, id: \.id) { record in
                    VStack(spacing: Self.timeGap) {
                        mark(before: Double(record.painBefore), after: record.painAfter.map { Double($0) }, size: size)
                            .frame(width: width, height: size.height)
                        Text(time(record.recordedDate)).modifier(RecordTextStyle(size: 12)).fixedSize()
                            .foregroundStyle(.secondary).frame(height: timeHeight)
                    }
                    .frame(width: column)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(time(record.recordedDate)), \(painDescription(before: Double(record.painBefore), after: record.painAfter.map { Double($0) }))")
                }
            }
            // 스크롤 뷰는 밖을 잘라서, 10점 원이 위로 반 넘치는 만큼 위에 자리를 두고 그만큼 올려 놓습니다
            .padding(.top, width/2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: size.width, height: width/2 + size.height + Self.timeGap + timeHeight, alignment: .topLeading)
        .padding(.top, -width/2)
    }
    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = state.calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    /// 복용 전·후 점수 사이를 막대로 그립니다. 주·일은 내려갔으면 초록·올라갔으면 주황으로 칠합니다.
    @ViewBuilder private func mark(before: Double, after: Double?, size: CGSize) -> some View {
        if let after {
            measuredMark(before: before, after: after, size: size)
        } else if usesRings {
            let y = size.height * (1 - RecordDisplay.fraction(before, maximum: 10))
            ZStack(alignment: .top) {
                Circle().fill(RecordChartStyle.decrease).frame(width: width, height: width).offset(y: y - width/2)
                Circle().fill(.white).frame(width: width * 0.6, height: width * 0.6).offset(y: y - width * 0.3)
            }.frame(height: size.height, alignment: .top)
        } else {
            // 사후 측정이 없으면 복용 전 점수만 표시하고 변화 막대는 그리지 않습니다.
            Circle().fill(RecordChartStyle.green).frame(width: width, height: width)
                .offset(y: size.height * (1 - RecordDisplay.fraction(before, maximum: 10)) - width/2)
                .frame(height: size.height, alignment: .top)
        }
    }
    private func painDescription(before: Double, after: Double?) -> String {
        let afterText = after.map { "복용 후 \(RecordDisplay.number($0))점" } ?? "사후 통증 미기록"
        return "복용 전 \(RecordDisplay.number(before))점, \(afterText)"
    }
    private func measuredMark(before: Double, after: Double, size: CGSize) -> some View {
        let top = size.height * (1 - RecordDisplay.fraction(max(before, after), maximum: 10))
        let bottom = size.height * (1 - RecordDisplay.fraction(min(before, after), maximum: 10))
        return ZStack(alignment: .top) {
            if usesRings {
                // 10점·0점의 원이 잘리지 않도록 색 막대를 원 반지름만큼 위아래로 늘립니다.
                Capsule().fill(after > before ? RecordChartStyle.increase : RecordChartStyle.decrease)
                    .frame(width: width, height: bottom - top + width).offset(y: top - width/2)
                ForEach([top, bottom].indices, id: \.self) { index in
                    let y = [top, bottom][index]
                    Circle().fill(.white.opacity(0.5)).frame(width: width, height: width).offset(y: y - width/2)
                    Circle().fill(.white).frame(width: width * 0.6, height: width * 0.6).offset(y: y - width * 0.3)
                }
            } else {
                Capsule().fill(RecordChartStyle.green).frame(width: width, height: max(bottom-top, width)).offset(y: top)
            }
        }.frame(height: size.height, alignment: .top)
    }
}

#Preview { NavigationStack { PainRecordDetailView() } }
