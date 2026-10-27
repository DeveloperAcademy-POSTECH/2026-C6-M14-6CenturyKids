import XCTest
@testable import PrevisitScreens

@MainActor
final class PrevisitLetterViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return value
    }

    func testLettersGroupByMonthNewestFirstAndShowSendDayAndBadges() throws {
        var sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 9)))
        let viewModel = PrevisitLetterViewModel(calendar: calendar, now: { sendTime })
        XCTAssertTrue(viewModel.months.isEmpty)

        let recordDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 24)))
        let day = PrevisitDay(id: "saved-day", dateLabel: "9/24", weekday: "목요일", entries: ["저장한 기록"],
                              recordedDate: recordDay, painBefore: 7, painAfter: 6, symptomCount: 2)
        viewModel.send(.init(day: day, letter: "\n  배가 아팠어요\n장이 꼬여요", mood: .comfortable), to: "학로쌤")
        sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23)))
        viewModel.send(.init(day: PrevisitDay(id: "d2", dateLabel: "9/29", weekday: "화요일", entries: ["e"], painBefore: 3, painAfter: 2),
                             letter: "", mood: .slowly), to: "학로쌤")
        sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9)))
        viewModel.send(.init(day: nil, letter: "어지러워요", mood: .unsure), to: "학로쌤")

        XCTAssertEqual(viewModel.months.map(\.id), ["2026년 10월", "2026년 9월"])
        XCTAssertEqual(viewModel.months[1].letters.map(\.draft.letter), ["", "\n  배가 아팠어요\n장이 꼬여요"])
        let first = try XCTUnwrap(viewModel.letters.last)
        // 고른 기록의 날(9/24)이 아니라 보낸 날
        XCTAssertEqual(viewModel.sentDate(first), "9월 27일")
        XCTAssertEqual(viewModel.recordDayTitle(day), "9월 24일 기록")
        XCTAssertEqual(viewModel.preview(first), "배가 아팠어요")
        XCTAssertEqual(viewModel.preview(viewModel.letters[1]), PrevisitMood.slowly.title)
        XCTAssertEqual(viewModel.badges(first), [.init(text: "통증 7점→6점", isAlert: true), .init(text: "증상2건", isAlert: false)])
        XCTAssertEqual(viewModel.badges(viewModel.letters[1]), [.init(text: "통증 3점→2점", isAlert: false)])
        XCTAssertEqual(viewModel.badges(viewModel.letters[0]), [])
    }

    func testSendingAgainOnSameDayOverwritesThatDay() throws {
        var sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 9)))
        let viewModel = PrevisitLetterViewModel(calendar: calendar, now: { sendTime })
        viewModel.send(.init(day: nil, letter: "어제", mood: .unsure), to: "학로쌤")
        sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9)))
        viewModel.send(.init(day: nil, letter: "아침", mood: .candid), to: "학로쌤")
        let morning = try XCTUnwrap(viewModel.latest?.id)

        sendTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 23, minute: 59)))
        viewModel.send(.init(day: nil, letter: "밤", mood: .slowly), to: "학로쌤")

        XCTAssertEqual(viewModel.letters.map(\.draft.letter), ["밤", "어제"])
        XCTAssertEqual(viewModel.latest?.id, morning, "같은 날 기록을 덮어쓰므로 id는 그대로")
        XCTAssertEqual(viewModel.latest?.sentAt, sendTime)
    }

    func testPainBadgeShowsBeforeScoreWhenAfterIsMissing() {
        let viewModel = PrevisitLetterViewModel(calendar: calendar)
        let waiting = PrevisitDay(id: "d", dateLabel: "10/27", weekday: "화요일", entries: ["e"], painBefore: 8, painAfter: nil)
        viewModel.send(.init(day: waiting, letter: "", mood: .unsure), to: "학로쌤")
        XCTAssertEqual(viewModel.badges(viewModel.letters[0]), [.init(text: "통증 8점", isAlert: true)])
    }

    func testEditSavesOnlyChangesAndDeleteRemoves() throws {
        let viewModel = PrevisitLetterViewModel(calendar: calendar)
        viewModel.send(.init(day: nil, letter: "배가 아팠어요", mood: .comfortable), to: "학로쌤")
        let id = try XCTUnwrap(viewModel.latest?.id)

        viewModel.beginEdit(id)
        XCTAssertFalse(viewModel.hasEditChanges)
        viewModel.saveEdit()
        XCTAssertNil(viewModel.notice, "고친 게 없으면 저장하지 않는다")

        viewModel.editingLetter = "  아직 배가 아파요\n"
        viewModel.editingMood = .carefully
        XCTAssertTrue(viewModel.hasEditChanges)
        viewModel.cancelEdit()
        XCTAssertEqual(viewModel.letter(id)?.draft.letter, "배가 아팠어요", "그만두면 고친 내용을 버린다")

        viewModel.beginEdit(id)
        viewModel.editingLetter = "  아직 배가 아파요\n"
        viewModel.editingMood = .carefully
        viewModel.saveEdit()
        XCTAssertNil(viewModel.editingID)
        XCTAssertEqual(viewModel.letter(id)?.draft.letter, "  아직 배가 아파요\n")
        XCTAssertEqual(viewModel.letter(id)?.draft.mood, .carefully)
        XCTAssertEqual(viewModel.notice, .saved)
        viewModel.clearNotice()

        viewModel.beginEdit(UUID())
        XCTAssertNil(viewModel.editingID, "없는 기록은 고치기 시작하지 않는다")
        viewModel.delete(id)
        XCTAssertNil(viewModel.letter(id))
        XCTAssertEqual(viewModel.notice, .deleted)
    }

    func testNoticeClearsItselfAfterDuration() async throws {
        let viewModel = PrevisitLetterViewModel(noticeDuration: .milliseconds(50))
        viewModel.send(.init(day: nil, letter: "", mood: .unsure), to: "학로쌤")
        let id = try XCTUnwrap(viewModel.latest?.id)
        viewModel.delete(id)
        XCTAssertEqual(viewModel.notice, .deleted)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(viewModel.notice, "화면이 지우지 않아도 정해진 시간 뒤 사라진다")
    }
}
