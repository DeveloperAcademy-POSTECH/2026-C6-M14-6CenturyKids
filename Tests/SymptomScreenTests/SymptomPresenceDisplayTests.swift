import XCTest
import ToDocDomain
@testable import SymptomScreens

final class SymptomPresenceDisplayTests: XCTestCase {
    func testSeparatesAbsentAndUnknownAnswersWithoutLosingOriginalDetails() {
        let present = entry(.present, detail: "구토 횟수: 두세 번 / 메스꺼움 시작: 어제")
        let absent = entry(.absent, detail: "없었어요")
        let unknown = entry(.unknown, detail: "[검토 필요] 잘 모르겠어요")
        let record = SymptomRecordDisplay(id: UUID(), recordedDate: .now, symptoms: [absent, present, unknown])

        XCTAssertEqual(record.entries(with: .present).map(\.id), [present.id])
        XCTAssertEqual(record.entries(with: .absent).map(\.id), [absent.id])
        XCTAssertEqual(record.entries(with: .unknown).map(\.id), [unknown.id])
        XCTAssertEqual(record.entries(with: .unknown).first?.detail, "[검토 필요] 잘 모르겠어요")
        XCTAssertEqual(record.entries(with: .present).first?.detail, "구토 횟수: 두세 번 / 메스꺼움 시작: 어제")
    }

    func testAllAbsentAndUnknownAnswersDoNotBecomePresentSymptoms() {
        let record = SymptomRecordDisplay(id: UUID(), recordedDate: .now,
                                          symptoms: [entry(.absent), entry(.unknown)])
        XCTAssertTrue(record.entries(with: .present).isEmpty)
        XCTAssertEqual(record.entries(with: .absent).count, 1)
        XCTAssertEqual(record.entries(with: .unknown).count, 1)
    }

    private func entry(_ presence: SymptomPresence, detail: String? = nil) -> SymptomEntryDisplay {
        .init(id: UUID(), symptomType: .nauseaVomiting, presence: presence, detail: detail)
    }
}
