//
//  PrevisitLetterViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/26/26.
//

import Foundation
import Observation

/// 보낸 진료 전 기록(고른 날·하고싶은말·기분)을 월별 목록·상세로 보여 주고, 하고싶은말·기분을 고치거나 지운다.
/// 저장 계약이 아직 없어 로그인 동안 메모리에만 둔다 (앱을 다시 켜면 사라진다)
@MainActor
@Observable
final class PrevisitLetterViewModel {
    /// 저장·삭제 뒤 화면이 잠깐 띄우는 안내
    enum Notice: Equatable {
        case saved, deleted
        var message: String {
            switch self {
            case .saved: "수정한 내용이 선생님께도 전달됐어요"
            case .deleted: "기록을 삭제했어요"
            }
        }
    }

    /// 목록의 한 달 묶음 ("2026년 10월")
    struct Month: Identifiable {
        let id: String
        let letters: [PrevisitLetter]
    }

    /// 목록 줄의 짧은 정보. isAlert는 통증 7점 이상 (빨간 배지)
    struct Badge: Hashable {
        let text: String
        let isAlert: Bool
    }

    /// 최신순
    private(set) var letters: [PrevisitLetter] = []
    /// 고치는 중인 기록 (nil이면 고치는 중이 아님)
    private(set) var editingID: UUID?
    var editingLetter = ""
    var editingMood: PrevisitMood?
    /// 잠깐 띄우는 안내. 띄운 뒤 noticeDuration이 지나면 스스로 사라진다
    /// (화면 전환 중에 토스트 뷰가 잠깐 사라졌다 나타나도 안내가 지워지지 않게 ViewModel이 시간을 잰다)
    private(set) var notice: Notice?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    private let noticeDuration: Duration
    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init, noticeDuration: Duration = .seconds(2)) {
        self.calendar = calendar
        self.now = now
        self.noticeDuration = noticeDuration
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

    func send(_ draft: PrevisitDraft, to doctorName: String) {
        cancelEdit()
        letters.insert(PrevisitLetter(id: UUID(), sentAt: now(), doctorName: doctorName, draft: draft), at: 0)
    }

    // MARK: - 수정·삭제

    func beginEdit(_ id: UUID) {
        guard let letter = letter(id) else { return }
        editingID = id
        editingLetter = letter.draft.letter
        editingMood = letter.draft.mood
    }

    /// 저장 버튼과 '수정을 그만둘까요?' 알림을 정한다
    var hasEditChanges: Bool {
        guard let editingID, let letter = letter(editingID) else { return false }
        return editingLetter != letter.draft.letter || editingMood != letter.draft.mood
    }

    /// 고친 원문을 그대로 남긴다 (편지는 선택 입력이라 빈 글도 허용, 기분은 비울 수 없다)
    func saveEdit() {
        guard hasEditChanges, let editingID, let editingMood,
              let index = letters.firstIndex(where: { $0.id == editingID }) else { return }
        letters[index].draft.letter = editingLetter
        letters[index].draft.mood = editingMood
        self.editingID = nil
        show(.saved)
    }

    func cancelEdit() { editingID = nil }

    func delete(_ id: UUID) {
        guard letters.contains(where: { $0.id == id }) else { return }
        letters.removeAll { $0.id == id }
        if editingID == id { cancelEdit() }
        show(.deleted)
    }

    func clearNotice() {
        noticeTask?.cancel()
        notice = nil
    }

    private func show(_ notice: Notice) {
        noticeTask?.cancel()
        self.notice = notice
        noticeTask = Task { [weak self, noticeDuration] in
            try? await Task.sleep(for: noticeDuration)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
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

    /// 통증(그날 마지막 기록)·증상 수. 기록이 없는 쪽은 빼고 보여 준다
    func badges(_ letter: PrevisitLetter) -> [Badge] {
        guard let day = letter.draft.day else { return [] }
        var result: [Badge] = []
        if let before = day.painBefore, let after = day.painAfter {
            result.append(Badge(text: "통증 \(before)점→\(after)점", isAlert: max(before, after) >= 7))
        }
        if day.symptomCount > 0 { result.append(Badge(text: "증상\(day.symptomCount)건", isAlert: false)) }
        return result
    }
}
