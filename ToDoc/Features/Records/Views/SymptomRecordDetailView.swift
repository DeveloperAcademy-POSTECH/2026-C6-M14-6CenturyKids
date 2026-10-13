import SwiftUI

struct SymptomRecordDetailView: View {
    @State var state = RecordDetailScreenState(kind: .symptom)
    var body: some View {
        RecordDetailLayout(state: state, editing: state.isEditing) {
            if case .symptom(let data) = state.content {
                RecordChartCard(caption: state.period == .day ? "하루 불편함 정도 평균" : "불편함 정도 평균",
                    value: data.averageSeverity.map { RecordDisplay.number($0) + "점" } ?? "점수 미제공", range: state.rangeLabel) {
                    RecordSymptomChart(state: state, days: data.days)
                }
                if state.period == .day {
                    if let record = data.days.first?.record, !record.symptoms.isEmpty { entries(record) }
                    else { Text("기록된 증상이 없어요.").foregroundStyle(.secondary) }
                }
            }
        }
    }
    @ViewBuilder private func entries(_ record: SymptomRecordDisplay) -> some View {
        HStack {
            Spacer()
            if state.isEditing {
                Button("취소") { state.isEditing = false }.disabled(state.isSaving)
                Button(state.isSaving ? "저장 중" : "완료") { state.onAction?(.saveScores(record.id, state.scoreTexts)) }
                    .disabled(state.isSaving || !state.canSave || state.onAction == nil)
            } else {
                Button("수정") {
                    state.scoreTexts = Dictionary(uniqueKeysWithValues: record.symptoms.map { ($0.id, $0.severity.map { String($0) } ?? "") })
                    state.isEditing = true
                }.disabled(state.onAction == nil)
            }
        }.modifier(RecordTextStyle(size: 16)).foregroundStyle(Color(white: 0.55))
        if let error = state.errorMessage { Text(error).foregroundStyle(.red) }
        ForEach(record.symptoms) { entry in
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { description(entry); Spacer(minLength: 8); score(entry) }
                    VStack(alignment: .leading, spacing: 12) { description(entry); score(entry) }
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 26))
        }
    }
    private func description(_ entry: SymptomEntryDisplay) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.symptomType.displayName).modifier(RecordTextStyle(size: 16, weight: .semibold))
            if let location = entry.rawLocationText, !location.isEmpty { Text(location).modifier(RecordTextStyle(size: 12)) }
            if let detail = entry.detail, !detail.isEmpty { Text(detail).modifier(RecordTextStyle(size: 12)) }
            if let count = entry.occurrenceCount { Text("횟수 \(count)회").modifier(RecordTextStyle(size: 12)).foregroundStyle(.secondary) }
        }.fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func score(_ entry: SymptomEntryDisplay) -> some View {
        if state.isEditing {
            TextField("없음", text: Binding(get: { state.scoreTexts[entry.id] ?? "" }, set: { state.scoreTexts[entry.id] = $0 }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
                .frame(width: 85).disabled(state.isSaving).accessibilityLabel(entry.symptomType.displayName + " 점수")
        } else {
            Text(entry.severity.map { RecordDisplay.number($0) + "점" } ?? "점수 없음")
                .modifier(RecordTextStyle(size: 20, weight: .bold)).fixedSize()
        }
    }
}

private struct RecordSymptomChart: View {
    let state: RecordDetailScreenState
    let days: [RecordSymptomDay]
    var body: some View {
        VStack(spacing: 12) {
            RecordPlot { size in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(state.days, id: \.self) { date in
                        let value = days.first { state.calendar.isDate($0.date, inSameDayAs: date) }?.averageSeverity
                        let width: CGFloat = state.period == .day ? 60 : state.period == .week ? 20 : 5
                        let height = size.height * RecordDisplay.fraction(value, maximum: 10)
                        ZStack(alignment: .bottom) {
                            if let value {
                                UnevenRoundedRectangle(topLeadingRadius: width/2, topTrailingRadius: width/2)
                                    .fill(RecordChartStyle.symptom).frame(width: width, height: max(height, 1))
                                if state.period != .month {
                                    Circle().fill(.white).overlay { Circle().strokeBorder(RecordDisplay.green, lineWidth: state.period == .day ? 8 : 4) }
                                        .frame(width: width, height: width).offset(y: -max(0, height - (state.period == .day ? width : width/2)))
                                    if state.period == .day {
                                        Text(RecordDisplay.number(value)).modifier(RecordTextStyle(size: 20, weight: .bold))
                                            .foregroundStyle(RecordDisplay.darkGreen).frame(width: width, height: width)
                                            .offset(y: -max(0, height - (state.period == .day ? width : width/2)))
                                    }
                                }
                            } else { Capsule().fill(Color(white: 0.85)).frame(width: width, height: 5) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(state.calendar.component(.month, from: date))월 \(state.calendar.component(.day, from: date))일")
                            .accessibilityValue(value.map { RecordDisplay.number($0) + "점" } ?? "점수 없음")
                    }
                }.frame(width: size.width, height: size.height)
            }
            RecordDateAxis(state: state)
        }
    }
}

#Preview { NavigationStack { SymptomRecordDetailView() } }
