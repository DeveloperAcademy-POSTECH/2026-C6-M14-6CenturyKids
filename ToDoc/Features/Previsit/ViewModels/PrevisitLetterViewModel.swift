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

/// 저장소에 전송된 기록을 조회하고, 새 기록을 전송합니다. 전송 후 변경 기능은 제공하지 않습니다.
@MainActor
@Observable
final class PrevisitLetterViewModel {
    typealias Load = () async throws -> [PrevisitRecord]
    typealias Save = (PrevisitRecord) async throws -> Void
    private let patientID: UUID?
    private let loadRecords: Load?
    private let saveRecord: Save?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
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

    init(patientID: UUID? = nil, calendar: Calendar = .current,
         load: Load? = nil, save: Save? = nil) {
        self.patientID = patientID
        self.calendar = calendar
        self.loadRecords = load
        self.saveRecord = save
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

    func reload() async { await load(days: days, doctorName: doctorName) }

    func send(_ draft: PrevisitDraft, to doctorName: String) async -> UUID? {
        guard !isSubmitting, let patientID, let saveRecord,
              let date = draft.day?.recordedDate, let mood = draft.mood else { return nil }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let record = try PrevisitRecord(patientId: patientID, selectedDate: date,
                                           memo: draft.letter.isEmpty ? nil : draft.letter, stateOfMind: mood)
            try await saveRecord(record)
            // 같은 날 재전송해도 이미 보낸 기록을 덮어쓰지 않습니다.
            letters.insert(PrevisitLetter(id: record.id, sentAt: record.submittedAt,
                                         doctorName: doctorName, draft: draft), at: 0)
            return record.id
        } catch {
            errorMessage = "전송하지 못했어요. 작성한 내용은 유지돼요. 다시 시도해 주세요."
            return nil
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
