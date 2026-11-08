import Foundation
import XCTest
import ToDocDomain

final class IntakeRecordTests: XCTestCase {
    func testMealUpdatePreservesPatientIdentityAndRecordedDate() {
        let id = UUID(), patientId = UUID(), date = Date(timeIntervalSince1970: 1_000)
        // 식사 내용을 수정해도 어느 환자의 기록인지 바뀌어서는 안 됩니다.
        var record = IntakeRecord(id: id, patientId: patientId, recordedDate: date, mealType: .breakfast, intakeAmount: .moderate)
        record.updateMealType(.lunch)
        record.updateIntakeAmount(.smallAmount)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.patientId, patientId)
        XCTAssertEqual(record.recordedDate, date)
        XCTAssertEqual(record.mealType, .lunch)
        XCTAssertEqual(record.intakeAmount, .smallAmount)
    }
}
