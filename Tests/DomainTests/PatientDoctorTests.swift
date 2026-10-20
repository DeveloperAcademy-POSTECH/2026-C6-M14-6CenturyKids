import Foundation
import XCTest
import ToDocDomain

final class PatientDoctorTests: XCTestCase {
    private func user() throws -> User {
        try User(id: UUID(), name: "김하늘", birthday: Date(timeIntervalSince1970: 0), sex: .female)
    }

    func testPatientCanUseAppWithoutDoctorOrDiagnosis() throws {
        let value = try user()
        // 의사 연결을 건너뛴 환자에게 임의의 의사 ID나 진단을 만들어 넣지 않습니다.
        let patient = Patient(user: value, doctorId: nil, disease: nil)
        XCTAssertEqual(patient.user.id, value.id)
        XCTAssertNil(patient.doctorId)
        XCTAssertNil(patient.disease)
    }

    func testLinkedPatientAndSeparateRecordsKeepTheirRelationshipIDs() throws {
        // 현재 구조는 큰 객체를 서로 품는 대신 ID로 연결합니다.
        // 환자 → doctorId → 의사 → hospitalId → 병원이며, 각 기록은 patientId를 가집니다.
        // 여기서는 실제 Model만 만들며 Repository 조회나 DB 저장은 실행하지 않습니다.
        let hospital = try Hospital(id: UUID(), name: "토닥 병원", code: "H12345", address: "포항시 남구 중앙로")
        let doctor = Doctor(user: try user(), code: "D12345", hospitalId: hospital.id)
        let disease = CarcinomaDetail(carcinoma: .thyroid, stage: .stage0)
        let patient = Patient(user: try user(), doctorId: doctor.user.id, disease: disease)
        let date = Date(timeIntervalSince1970: 1_000)
        let goal = try ExerciseGoal(id: UUID(), patientId: patient.user.id, doctorId: doctor.user.id,
                                    year: 2026, month: 10, targetCount: 20, exerciseRecords: [])
        let pain = try PainRecord(id: UUID(), patientId: patient.user.id, recordedDate: date,
            location: [BodyLocation(bodyPart: .neck, bodySide: .center, bodyView: .front)], painBefore: 5, painAfter: 3)
        let symptom = SymptomRecord(id: UUID(), patientId: patient.user.id, recordedDate: date,
                                    conditionText: nil, symptoms: [])
        let intake = IntakeRecord(id: UUID(), patientId: patient.user.id, recordedDate: date,
                                  mealType: .dinner, intakeAmount: .veryFull)

        XCTAssertEqual(patient.doctorId, doctor.user.id)
        XCTAssertEqual(doctor.hospitalId, hospital.id)
        XCTAssertEqual(patient.disease, disease)
        XCTAssertEqual(pain.patientId, patient.user.id)
        XCTAssertEqual(symptom.patientId, patient.user.id)
        XCTAssertEqual(intake.patientId, patient.user.id)
        XCTAssertEqual(goal.patientId, patient.user.id)
        XCTAssertEqual(goal.doctorId, doctor.user.id)
    }

    func testCopiedProfilesAndDiagnosisRemainSnapshots() throws {
        var originalDoctorUser = try user()
        var originalPatientUser = try user()
        var originalDisease = CarcinomaDetail(carcinoma: .thyroid, stage: .stage0)
        let doctor = Doctor(user: originalDoctorUser, code: "D12345", hospitalId: UUID())
        let patient = Patient(user: originalPatientUser, doctorId: doctor.user.id, disease: originalDisease)

        // 복사한 원본을 나중에 수정해도 이미 조회한 프로필·진단은 자동으로 바뀌지 않습니다.
        // 최신 정보가 필요하면 Repository에서 다시 받아야 합니다.
        try originalDoctorUser.updateName("김가을")
        try originalPatientUser.updateName("김겨울")
        originalDisease.updateStage(.stage4)
        XCTAssertEqual(originalDoctorUser.name, "김가을")
        XCTAssertEqual(originalPatientUser.name, "김겨울")
        XCTAssertEqual(originalDisease.stage, .stage4)
        XCTAssertEqual(doctor.user.name, "김하늘")
        XCTAssertEqual(patient.user.name, "김하늘")
        XCTAssertEqual(patient.disease?.stage, .stage0)
    }
}
