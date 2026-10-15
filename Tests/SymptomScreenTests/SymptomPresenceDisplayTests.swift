import XCTest
import ToDocDomain
@testable import SymptomScreens

final class SymptomPresenceDisplayTests: XCTestCase {
    func testDisplaysOnlyPresentSymptomsWithoutLosingOriginalAnswers() {
        let present = entry(.present, detail: "구토 횟수: 두세 번 / 메스꺼움 시작: 어제")
        let absent = entry(.absent, detail: "없었어요")
        let unknown = entry(.unknown, detail: "[검토 필요] 잘 모르겠어요")
        let record = SymptomRecordDisplay(id: UUID(), recordedDate: .now, symptoms: [absent, present, unknown])

        XCTAssertEqual(record.presentSymptoms.map(\.id), [present.id])
        XCTAssertEqual(record.presentSymptoms.first?.detail, "구토 횟수: 두세 번 / 메스꺼움 시작: 어제")
        XCTAssertEqual(record.symptoms.map(\.id), [absent.id, present.id, unknown.id])
        XCTAssertEqual(record.symptoms.map(\.presence), [.absent, .present, .unknown])
        XCTAssertEqual(record.symptoms.first?.detail, "없었어요")
        XCTAssertEqual(record.symptoms.last?.detail, "[검토 필요] 잘 모르겠어요")
    }

    func testAllAbsentAndUnknownAnswersRemainStoredButAreNotDisplayed() {
        let record = SymptomRecordDisplay(id: UUID(), recordedDate: .now,
                                          symptoms: [entry(.absent), entry(.unknown)])
        XCTAssertTrue(record.presentSymptoms.isEmpty)
        XCTAssertEqual(record.symptoms.map(\.presence), [.absent, .unknown])
    }

    private func entry(_ presence: SymptomPresence, detail: String? = nil) -> SymptomEntryDisplay {
        .init(id: UUID(), symptomType: .nauseaVomiting, presence: presence, detail: detail)
    }
}
