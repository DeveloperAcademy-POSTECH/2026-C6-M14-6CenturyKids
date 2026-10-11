import Foundation
import XCTest
import ToDocDomain

final class IntakeRecordTests: XCTestCase {
    func testMealUpdatePreservesIdentityAndRecordedDate() {
        let id = UUID(), date = Date(timeIntervalSince1970: 1_000)
        var record = IntakeRecord(id: id, recordedDate: date, mealType: .breakfast, intakeAmount: .moderate)
        record.updateMealType(.lunch)
        record.updateIntakeAmount(.smallAmount)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.recordedDate, date)
        XCTAssertEqual(record.mealType, .lunch)
        XCTAssertEqual(record.intakeAmount, .smallAmount)
    }
}
