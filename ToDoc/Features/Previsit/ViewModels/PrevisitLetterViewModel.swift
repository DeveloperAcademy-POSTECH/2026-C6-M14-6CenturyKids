//
//  PrevisitLetterViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/26/26.
//

import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Observation

/// 저장소에 전송된 기록을 조회하고, 새 기록을 전송합니다.
/// 진료 전 기록은 보낸 날 기준 하루에 한 번만 보낼 수 있고, 보낸 날(달력 기준)이 오늘인 기록만 고치거나 지울 수 있습니다.
@MainActor
@Observable
final class PrevisitLetterViewModel {
    typealias Load = () async throws -> [PrevisitRecord]
    typealias LoadDay = (Date) async throws -> PrevisitDay?
    typealias Save = (PrevisitRecord) async throws -> Void
    typealias Delete = (UUID) async throws -> Void
    let allowsMultiplePerDay: Bool
    private let patientID: UUID?
    private let loadRecords: Load?
    private let saveRecord: Save?
    private let deleteRecord: Delete?
    private let loadDay: LoadDay?
    private(set) var loadingDetails: Set<UUID> = []
    private(set) var detailErrors: [UUID: String] = [:]
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    /// 수정·삭제 결과 토스트. 화면 전환 중에도 사라지지 않게 시간은 여기서 셉니다.
    private(set) var notice: String?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    private var days: [PrevisitDay] = []
    private var doctorName = "선생님"

    /// 목록의 한 달 묶음 ("2026년 10월")
    struct Month: Identifiable {
        let id: String
        let letters: [PrevisitLetter]
    }

    /// 최신순
    private(set) var letters: [PrevisitLetter] = []
    private let calendar: Calendar
    private let now: () -> Date

    init(patientID: UUID? = nil, calendar: Calendar = .current, now: @escaping () -> Date = { .now },
         load: Load? = nil, save: Save? = nil, loadDay: LoadDay? = nil, delete: Delete? = nil, allowsMultiplePerDay: Bool = false) {
        self.allowsMultiplePerDay = allowsMultiplePerDay
        self.patientID = patientID
        self.calendar = calendar
        self.now = now
        self.loadRecords = load
        self.saveRecord = save
        self.deleteRecord = delete
        self.loadDay = loadDay
    }

    func load(days: [PrevisitDay], doctorName: String) async {
        guard let loadRecords, !isLoading else { return }
        self.days = days
        self.doctorName = doctorName
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let records = try await loadRecords()
            try Task.checkCancellation()
            letters = records.sorted { $0.submittedAt > $1.submittedAt }.map(display)
        } catch {
            if !Task.isCancelled { errorMessage = "진료 전 기록을 불러오지 못했어요. 다시 시도해 주세요." }
        }
    }

    /// 상세에서는 대표 배지와 별개로 선택한 날짜의 전체 기록을 다시 조회합니다.
    func loadDetail(_ id: UUID) async {
        guard let loadDay, let letter = letter(id), let date = letter.draft.day?.recordedDate,
              !loadingDetails.contains(id) else { return }
        loadingDetails.insert(id)
        detailErrors[id] = nil
        defer { loadingDetails.remove(id) }
        do {
            let day = try await loadDay(date)
            try Task.checkCancellation()
            guard let index = letters.firstIndex(where: { $0.id == id }) else { return }
            var draft = letter.draft
            // 조회 결과가 비어도 이전 기록을 남기지 않습니다.
            draft.day = day ?? PrevisitDay(id: date.description, dateLabel: letter.draft.day?.dateLabel ?? "",
                                          weekday: letter.draft.day?.weekday ?? "", entries: [], recordedDate: date)
            letters[index] = PrevisitLetter(id: letter.id, sentAt: letter.sentAt,
                                           doctorName: letter.doctorName, draft: draft)
        } catch {
            if !Task.isCancelled { detailErrors[id] = "해당 날짜의 기록을 불러오지 못했어요. 다시 시도해 주세요." }
        }
    }

    func reload() async { await load(days: days, doctorName: doctorName) }

    /// 선택한 기록 날짜와 관계없이 전송 시각을 기준으로 찾습니다.
    var todaySentLetter: PrevisitLetter? {
        let today = now()
        return letters.first { calendar.isDate($0.sentAt, inSameDayAs: today) }
    }

    var hasSentToday: Bool { todaySentLetter != nil }

    func send(_ draft: PrevisitDraft, to doctorName: String,
              startTracking: () -> PrevisitAnalytics.Submission? = { nil }) async -> UUID? {
        guard !isSubmitting, let patientID, let saveRecord,
              let date = draft.day?.recordedDate, let mood = draft.mood else { return nil }
        guard allowsMultiplePerDay || !hasSentToday else {
            errorMessage = "진료 전 기록은 하루에 한 번만 보낼 수 있어요."
            return nil
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        var submission: PrevisitAnalytics.Submission?
        do {
            let record = try PrevisitRecord(patientId: patientID, selectedDate: date,
                                           memo: draft.letter.isEmpty ? nil : draft.letter, stateOfMind: mood)
            submission = startTracking()
            try await saveRecord(record)
            submission?.finish()
            letters.insert(PrevisitLetter(id: record.id, sentAt: record.submittedAt,
                                         doctorName: doctorName, draft: draft), at: 0)
            return record.id
        } catch {
            submission?.finish(error: error)
            errorMessage = "기기에 저장하지 못했어요. 작성한 내용은 유지돼요. 저장 공간을 확인하고 다시 시도해 주세요."
            return nil
        }
    }

    /// 24시간이 아니라 날짜로 봅니다: 어제 밤에 보낸 기록은 오늘 고칠 수 없습니다.
    func canEdit(_ letter: PrevisitLetter) -> Bool { calendar.isDate(letter.sentAt, inSameDayAs: now()) }

    /// 하고싶은말·기분만 고칩니다. 보낸 시각은 그대로 둬서 하루 한 번 규칙과 목록 순서가 바뀌지 않습니다.
    /// 바뀐 게 없으면 저장하지 않고 true를 돌려줍니다.
    func update(_ id: UUID, letter text: String? = nil, mood: StateOfMind? = nil) async -> Bool {
        guard !isSubmitting, let patientID, let saveRecord, let current = letter(id), canEdit(current),
              let date = current.draft.day?.recordedDate else { return false }
        var draft = current.draft
        if let text { draft.letter = text }
        if let mood { draft.mood = mood }
        guard draft.letter != current.draft.letter || draft.mood != current.draft.mood else { return true }
        guard let newMood = draft.mood else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let record = try PrevisitRecord(id: id, patientId: patientID, selectedDate: date,
                                           memo: draft.letter.isEmpty ? nil : draft.letter,
                                           stateOfMind: newMood, submittedAt: current.sentAt)
            // 같은 id로 upsert하면 서버에서는 수정(UPDATE)이 됩니다.
            try await saveRecord(record)
            if let index = letters.firstIndex(where: { $0.id == id }) {
                letters[index].draft.letter = draft.letter
                letters[index].draft.mood = draft.mood
            }
            show("수정이 완료되었어요")
            return true
        } catch {
            print("[진료 전] 수정 실패: \(type(of: error))")
            show("수정하지 못했어요. 다시 시도해 주세요.")
            return false
        }
    }

    func delete(_ id: UUID) async -> Bool {
        guard !isSubmitting, let deleteRecord, let current = letter(id), canEdit(current) else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await deleteRecord(id)
            letters.removeAll { $0.id == id }
            return true
        } catch {
            print("[진료 전] 삭제 실패: \(type(of: error))")
            show("삭제하지 못했어요. 다시 시도해 주세요.")
            return false
        }
    }

    private func show(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    private func display(_ record: PrevisitRecord) -> PrevisitLetter {
        let day = days.first { $0.recordedDate.map { calendar.isDate($0, inSameDayAs: record.selectedDate) } == true }
            ?? PrevisitDay(id: record.selectedDate.description,
                           dateLabel: "\(calendar.component(.month, from: record.selectedDate))/\(calendar.component(.day, from: record.selectedDate))",
                           weekday: calendar.weekdaySymbols[calendar.component(.weekday, from: record.selectedDate) - 1],
                           entries: [], recordedDate: record.selectedDate)
        return PrevisitLetter(id: record.id, sentAt: record.submittedAt, doctorName: doctorName,
                              draft: .init(day: day, letter: record.memo ?? "", mood: record.stateOfMind))
    }

    var latest: PrevisitLetter? { letters.first }

    func letter(_ id: UUID) -> PrevisitLetter? { letters.first { $0.id == id } }

    /// 보낸 달마다 묶고, 달과 그 안의 기록 모두 최신순
    var months: [Month] {
        var result: [Month] = []
        for letter in letters {
            let title = "\(calendar.component(.year, from: letter.sentAt))년 \(calendar.component(.month, from: letter.sentAt))월"
            if result.last?.id == title {
                result[result.count - 1] = Month(id: title, letters: result[result.count - 1].letters + [letter])
            } else {
                result.append(Month(id: title, letters: [letter]))
            }
        }
        return result
    }

    // MARK: - 표시 문구

    /// 보낸 날: "10월 18일"
    func sentDate(_ letter: PrevisitLetter) -> String {
        "\(calendar.component(.month, from: letter.sentAt))월 \(calendar.component(.day, from: letter.sentAt))일"
    }

    /// 고른 기록의 날: "10월 18일 기록" (날짜가 없으면 저장할 때 만든 "10/18")
    func recordDayTitle(_ day: PrevisitDay) -> String {
        guard let date = day.recordedDate else { return "\(day.dateLabel) 기록" }
        return "\(calendar.component(.month, from: date))월 \(calendar.component(.day, from: date))일 기록"
    }

    /// 목록 미리보기: 하고싶은말 첫 줄, 없으면 기분
    func preview(_ letter: PrevisitLetter) -> String {
        let firstLine = letter.draft.letter.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
        return firstLine ?? letter.draft.mood?.title ?? "남긴 말 없음"
    }

    /// 통증(PrevisitDay가 고른 그날 기록)·증상 수. 기록이 없는 쪽은 빼고 보여 준다.
    /// 복용 후 점수를 아직 남기지 않은 통증은 복용 전 점수만 보여 준다
    func badges(_ letter: PrevisitLetter) -> [String] {
        guard let day = letter.draft.day else { return [] }
        var result: [String] = []
        if let before = day.painBefore {
            result.append(day.painAfter.map { "통증 \(before)점→\($0)점" } ?? "통증 \(before)점")
        }
        if day.symptomCount > 0 { result.append("증상\(day.symptomCount)건") }
        return result
    }
}
