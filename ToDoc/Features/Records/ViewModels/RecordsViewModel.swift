//
//  RecordsViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/21/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation
import Observation

/// 기록 목록('내 기록') 화면의 상태를 보관한다: 하루 이동, 그날 통증·하루 기록 요약, 카드를 누르면 그날로 상세 열기.
/// 집계는 기록 상세와 같은 기준(RecordDetailViewModel)을 쓴다
@MainActor
@Observable
final class RecordsViewModel {
    let state = RecordsScreenState()
    private let patientId: UUID
    private let painRepository: any PainRepository
    private let symptomRepository: any SymptomRepository
    private let detail: RecordDetailViewModel
    private let calendar: Calendar
    private let now: () -> Date
    /// 보고 있는 날 (그날 0시)
    private var day: Date
    @ObservationIgnored private var load: Task<Void, Never>?

    init(patientId: UUID, painRepository: any PainRepository, symptomRepository: any SymptomRepository,
         detail: RecordDetailViewModel, calendar: Calendar = RecordDetailViewModel.calendar,
         now: @escaping () -> Date = Date.init) {
        self.patientId = patientId
        self.painRepository = painRepository
        self.symptomRepository = symptomRepository
        self.detail = detail
        self.calendar = calendar
        self.now = now
        day = calendar.startOfDay(for: now())
        state.dateLabel = Self.dayLabel(day, calendar: calendar)
        state.loadState = .idle
        state.onAction = { [weak self] action in self?.handle(action) }
    }

    private func handle(_ action: RecordsAction) {
        switch action {
        case .load:
            reload()
        case .moveDay(let offset):
            // 오늘 뒤로는 넘어가지 않는다
            guard let moved = calendar.date(byAdding: .day, value: offset, to: day),
                  moved <= calendar.startOfDay(for: now()) else { return }
            day = moved
            state.dateLabel = Self.dayLabel(day, calendar: calendar)
            reload()
        case .select(let kind):
            detail.show(kind, at: day)
        case .cancel:
            load?.cancel()
            load = nil
            if state.loadState == .loading { state.loadState = .idle }
        }
    }

    private func reload() {
        load?.cancel()
        state.loadState = .loading
        let day = day
        load = Task { [weak self] in
            guard let self else { return }
            do {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                // 통증 저장소는 끝 날짜 당일까지 포함하고, 증상 저장소는 끝 날짜를 뺀다
                async let pains = painRepository.findByPatientIdAndDate(patientId: patientId, from: day, to: day)
                async let symptoms = symptomRepository.findByPatientIdAndDate(patientId: patientId, from: day, to: tomorrow)
                let snapshot = Self.snapshot(day: day, pains: try await pains, symptoms: try await symptoms, calendar: calendar)
                guard !Task.isCancelled else { return }
                state.snapshot = snapshot
                state.loadState = .loaded
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                state.loadState = .failed("기록을 불러오지 못했어요.")
            }
        }
    }

    /// 10월 2일 화요일
    static func dayLabel(_ day: Date, calendar: Calendar) -> String {
        let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: day) - 1]
        return RecordDetailViewModel.monthDay(day, calendar) + " " + weekday
    }

    /// 그날 통증(평균 복용 전·후와 차이)과 그날 '있음'인 증상. 기록이 없으면 nil
    static func snapshot(day: Date, pains: [PainRecord], symptoms: [SymptomRecord], calendar: Calendar) -> RecordOverviewSnapshot {
        let todayPains = pains.filter { calendar.isDate($0.recordedDate, inSameDayAs: day) }
        let today = symptoms.filter { calendar.isDate($0.recordedDate, inSameDayAs: day) }
        return RecordOverviewSnapshot(
            pain: RecordDetailViewModel.painDetail(todayPains, period: .day, calendar: calendar).days.first.map { day in
                .init(averageBefore: day.averageBefore, averageAfter: day.averageAfter,
                      difference: RecordDetailViewModel.pairedDifference(todayPains))
            },
            symptom: today.isEmpty ? nil : .init(
                presentCount: today.flatMap(\.symptoms).filter { $0.presence == .present }.count,
                types: RecordDetailViewModel.symptomDetail(today, period: .day, calendar: calendar).symptoms.map(\.type)))
    }
}
