//
//  RecordDetailViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/21/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 기록 상세(통증·하루 기록) 화면의 상태를 보관한다: 기간(일/주/월) 이동, 기간 조회, 집계.
/// 집계 기준은 노션 '기록상세확인'을 따른다. 통증은 하루 차이(평균 복용 전 − 평균 복용 후)를 기록한 날 수로 평균 내고,
/// 하루 기록은 증상마다 '있음'으로 답한 날 수로 크기를 정한다
@MainActor
@Observable
final class RecordDetailViewModel {
    let pain = RecordDetailScreenState(kind: .pain)
    let symptom = RecordDetailScreenState(kind: .symptom)
    private let patientId: UUID
    private let painRepository: any PainRepository
    private let symptomRepository: any SymptomRepository
    private let calendar: Calendar
    private let now: () -> Date
    /// 화면마다 보고 있는 기간 안의 날짜 (처음은 오늘)
    private var anchors: [RecordOverviewKind: Date] = [:]
    @ObservationIgnored private var loads: [RecordOverviewKind: Task<Void, Never>] = [:]

    init(patientId: UUID, painRepository: any PainRepository, symptomRepository: any SymptomRepository,
         calendar: Calendar = RecordDetailViewModel.calendar, now: @escaping () -> Date = Date.init) {
        self.patientId = patientId
        self.painRepository = painRepository
        self.symptomRepository = symptomRepository
        self.calendar = calendar
        self.now = now
        for state in [pain, symptom] {
            state.calendar = calendar
            let kind = state.kind
            state.onAction = { [weak self] action in self?.handle(action, for: kind) }
            showPeriod(of: state)
        }
    }

    /// 시안의 주간 축(M T W T F S S)에 맞춰 월요일에 주를 시작한다
    nonisolated static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func state(_ kind: RecordOverviewKind) -> RecordDetailScreenState { kind == .pain ? pain : symptom }

    private func handle(_ action: RecordDetailAction, for kind: RecordOverviewKind) {
        let state = state(kind)
        switch action {
        case .load:
            load(kind)
        case .movePeriod(let offset):
            let anchor = anchors[kind] ?? now()
            guard let moved = calendar.date(byAdding: state.period.component, value: offset, to: anchor),
                  let start = interval(of: state.period, containing: moved)?.start,
                  start <= now() else { return }
            anchors[kind] = moved
            load(kind)
        case .selectPeriod(let period):
            guard state.period != period else { return }
            state.period = period
            load(kind)
        case .edit:
            // 하루 기록 수정은 다음 작업에서 연결한다 (그 전까지 화면은 canEdit == false라 버튼을 숨긴다)
            break
        case .cancel:
            loads[kind]?.cancel()
            loads[kind] = nil
            if state.loadState == .loading { state.loadState = .idle }
        }
    }

    private func load(_ kind: RecordOverviewKind) {
        let state = state(kind)
        loads[kind]?.cancel()
        guard let interval = showPeriod(of: state) else {
            state.loadState = .failed("기간을 계산하지 못했어요.")
            return
        }
        state.loadState = .loading
        let period = state.period
        loads[kind] = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await fetch(kind, in: interval, period: period)
                guard !Task.isCancelled else { return }
                state.content = content
                state.loadState = .loaded
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                state.loadState = .failed("기록을 불러오지 못했어요.")
            }
        }
    }

    private func fetch(_ kind: RecordOverviewKind, in interval: DateInterval, period: RecordPeriod) async throws -> RecordDetailContent {
        switch kind {
        case .pain:
            // 통증 저장소는 끝 날짜 당일까지 포함한다
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            let records = try await painRepository.findByPatientIdAndDate(patientId: patientId, from: interval.start, to: lastDay)
            return .pain(Self.painDetail(records, period: period, calendar: calendar))
        case .symptom:
            // 증상 저장소는 끝 날짜를 빼고 찾는다 (다음 기간의 첫날)
            let records = try await symptomRepository.findByPatientIdAndDate(patientId: patientId, from: interval.start, to: interval.end)
            return .symptom(Self.symptomDetail(records, period: period, calendar: calendar))
        }
    }

    // MARK: - 기간

    /// 보고 있는 기간의 표시(기간 이름·날짜 범위·축 날짜)를 채우고 그 기간을 돌려준다
    @discardableResult
    private func showPeriod(of state: RecordDetailScreenState) -> DateInterval? {
        guard let interval = interval(of: state.period, containing: anchors[state.kind] ?? now()) else { return nil }
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        state.days = Self.days(in: interval, calendar: calendar)
        state.periodLabel = Self.periodLabel(state.period, start: interval.start, calendar: calendar)
        state.rangeLabel = state.period == .day ? "" : "\(Self.monthDay(interval.start, calendar)) ~ \(Self.monthDay(lastDay, calendar))"
        return interval
    }

    private func interval(of period: RecordPeriod, containing date: Date) -> DateInterval? {
        calendar.dateInterval(of: period.component, for: date)
    }

    static func days(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var day = interval.start
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// 9월 17일 / 9월 4번째 주 / 9월. 주는 목요일이 든 달의 몇 번째 주인지로 센다 (달을 걸친 주도 한 달에만 속하게)
    static func periodLabel(_ period: RecordPeriod, start: Date, calendar: Calendar) -> String {
        switch period {
        case .day:
            return monthDay(start, calendar)
        case .week:
            let thursday = calendar.date(byAdding: .day, value: 3, to: start) ?? start
            let day = calendar.component(.day, from: thursday)
            return "\(calendar.component(.month, from: thursday))월 \((day - 1) / 7 + 1)번째 주"
        case .month:
            return "\(calendar.component(.month, from: start))월"
        }
    }

    private static func monthDay(_ date: Date, _ calendar: Calendar) -> String {
        "\(calendar.component(.month, from: date))월 \(calendar.component(.day, from: date))일"
    }

    // MARK: - 집계

    /// 날마다 평균 복용 전·후를 그래프로, 기록한 날들의 하루 차이 평균을 문구로. 일별은 기록마다 시간축에 그린다
    static func painDetail(_ records: [PainRecord], period: RecordPeriod, calendar: Calendar) -> RecordPainDetail {
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.recordedDate) }
        let days: [RecordPainDay] = grouped.map { date, records in
            let count = Double(records.count)
            let before = Double(records.reduce(0) { $0 + $1.painBefore }) / count
            let after = Double(records.reduce(0) { $0 + $1.painAfter }) / count
            return RecordPainDay(date: date, averageBefore: before, averageAfter: after)
        }.sorted { $0.date < $1.date }
        let differences = days.map { $0.averageBefore - $0.averageAfter }
        let average: Double? = days.isEmpty ? nil : differences.reduce(0, +) / Double(days.count)
        var displays: [PainRecordDisplay]?
        if period == .day {
            displays = records.sorted { $0.recordedDate < $1.recordedDate }.map {
                PainRecordDisplay(id: $0.id, recordedDate: $0.recordedDate, painBefore: $0.painBefore, painAfter: $0.painAfter)
            }
        }
        return RecordPainDetail(averageDifference: average, days: days, records: displays)
    }

    /// 일: 그날 '있음'인 증상을 같은 크기로, 말풍선은 그날 답한 횟수(N회)나 시간(N분).
    /// 주·월: 증상마다 '있음'으로 나타난 날 수로 크기를 정하고 말풍선은 N번 (같은 날 부위별 항목이 여러 개여도 하루).
    /// 많은 순, 같으면 증상 순서대로 (화면은 이 순서로 배치·색을 정한다)
    static func symptomDetail(_ records: [SymptomRecord], period: RecordPeriod, calendar: Calendar) -> RecordSymptomDetail {
        var entries: [SymptomType: [SymptomEntry]] = [:]
        var days: [SymptomType: Set<Date>] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.recordedDate)
            for entry in record.symptoms where entry.presence == .present {
                entries[entry.symptomType, default: []].append(entry)
                days[entry.symptomType, default: []].insert(day)
            }
        }
        let symptoms: [RecordSymptomItem] = SymptomType.allCases.compactMap { type in
            guard let found = entries[type], let count = days[type]?.count else { return nil }
            return period == .day
                ? RecordSymptomItem(type: type, weight: 1, label: amount(of: found))
                : RecordSymptomItem(type: type, weight: Double(count), label: "\(count)번")
        }
        let order = { (type: SymptomType) in SymptomType.allCases.firstIndex(of: type) ?? 0 }
        return RecordSymptomDetail(
            symptoms: symptoms.sorted { $0.weight != $1.weight ? $0.weight > $1.weight : order($0.type) < order($1.type) },
            records: records.sorted { $0.recordedDate < $1.recordedDate }.map(SymptomRecordDisplay.init(record:)))
    }

    /// 그날 답한 양: 횟수가 있으면 부위별 항목의 횟수를 더하고, 없으면 가장 긴 시간. 둘 다 없으면 말풍선을 띄우지 않는다
    private static func amount(of entries: [SymptomEntry]) -> String? {
        let counts = entries.compactMap(\.occurrenceCount)
        if !counts.isEmpty { return "\(counts.reduce(0, +))회" }
        return entries.compactMap(\.durationMinutes).max().map { "\($0)분" }
    }
}
