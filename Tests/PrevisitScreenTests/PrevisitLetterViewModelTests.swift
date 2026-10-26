import XCTest
@testable import PrevisitScreens

@MainActor
final class PrevisitLetterViewModelTests: XCTestCase {
    func testSendThenEditKeepsRawLetterAndLabelsLastSentDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let sentAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 9)))
        let viewModel = PrevisitLetterViewModel(calendar: calendar, now: { sentAt })
        XCTAssertNil(viewModel.sent)
        XCTAssertEqual(viewModel.lastSentLabel, "기록 없음")
        viewModel.beginEdit()
        XCTAssertFalse(viewModel.isEditing, "보낸 기록 없이 고치기 시작하지 않는다")

        let day = PrevisitDay(id: "saved-day", dateLabel: "10/24", weekday: "토요일", entries: ["저장한 기록"])
        viewModel.send(.init(day: day, letter: "배가 아팠어요", mood: .comfortable), to: "학로쌤")
        XCTAssertEqual(viewModel.lastSentLabel, "10월 26일 마지막 기록")
        XCTAssertEqual(viewModel.doctorName, "학로쌤")

        viewModel.beginEdit()
        XCTAssertEqual(viewModel.editingLetter, "배가 아팠어요")
        viewModel.editingLetter = "  아직 배가 아파요\n"
        viewModel.finishEdit()
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertEqual(viewModel.sent?.letter, "  아직 배가 아파요\n")
        XCTAssertEqual(viewModel.sent?.day, day)
        XCTAssertEqual(viewModel.sent?.mood, .comfortable)

        viewModel.finishEdit() // 고치는 중이 아니면 아무것도 바꾸지 않는다
        XCTAssertEqual(viewModel.sent?.letter, "  아직 배가 아파요\n")
    }
}
