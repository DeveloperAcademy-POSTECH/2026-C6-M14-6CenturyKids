import Foundation
import XCTest
import ToDocDomain

final class PatientDoctorTests: XCTestCase {
    private func user() throws -> User {
        try User(id: UUID(), email: "user@example.com", name: "김하늘", birthday: Date(timeIntervalSince1970: 0), sex: .female)
    }
    func testPatientCanUseAppWithoutDoctorOrDiagnosis() throws {
        let value = try user()
        let patient = Patient(user: value, doctor: nil, disease: nil, painRecords: [],
                              symptomRecords: [], intakeRecords: [], exerciseGoals: [])
        XCTAssertEqual(patient.user.id, value.id)
        XCTAssertNil(patient.doctor)
        XCTAssertNil(patient.disease)
    }
    func testLinkedPatientPreservesHospitalAndAllRecordFamilies() throws {
        let hospital = try Hospital(id: UUID(), name: "토닥 병원", code: "H12345", address: "포항시 남구 중앙로", doctors: [])
        let goal = try ExerciseGoal(id: UUID(), year: 2026, month: 10, targetCount: 20, exerciseRecords: [])
        let doctor = Doctor(user: try user(), code: "D12345", patients: [], hospital: hospital, exerciseGoals: [goal])
        let date = Date(timeIntervalSince1970: 1_000)
        let pain = try PainRecord(id: UUID(), recordedDate: date,
            location: [BodyLocation(bodyPart: .neck, bodySide: .center, bodyView: .front)], painBefore: 5, painAfter: 3)
        let symptom = SymptomRecord(id: UUID(), recordedDate: date, symptoms: [])
        let intake = IntakeRecord(id: UUID(), recordedDate: date, mealType: .dinner, intakeAmount: .veryFull)
        let disease = CarcinomaDetail(carcinoma: .thyroid, stage: .stage0)
        let patient = Patient(user: try user(), doctor: doctor, disease: disease, painRecords: [pain],
                              symptomRecords: [symptom], intakeRecords: [intake], exerciseGoals: [goal])
        XCTAssertEqual(patient.doctor?.user.id, doctor.user.id)
        XCTAssertEqual(patient.doctor?.hospital.id, hospital.id)
        XCTAssertEqual(patient.doctor?.exerciseGoals.map(\.id), [goal.id])
        XCTAssertEqual(patient.disease, disease)
        XCTAssertEqual(patient.painRecords.map(\.id), [pain.id])
        XCTAssertEqual(patient.symptomRecords.map(\.id), [symptom.id])
        XCTAssertEqual(patient.intakeRecords.map(\.id), [intake.id])
        XCTAssertEqual(patient.exerciseGoals.map(\.id), [goal.id])
        let populatedDoctor = Doctor(user: doctor.user, code: doctor.code, patients: [patient],
                                     hospital: hospital, exerciseGoals: [goal])
        let populatedHospital = try Hospital(id: hospital.id, name: hospital.name, code: hospital.code,
                                            address: hospital.address, doctors: [populatedDoctor])
        XCTAssertEqual(populatedHospital.doctors.first?.patients.first?.user.id, patient.user.id)
    }
    func testCopiedRelationshipValuesRemainSnapshots() throws {
        var hospital = try Hospital(id: UUID(), name: "토닥 병원", code: "H12345", address: "포항시 남구 중앙로", doctors: [])
        var originalUser = try user()
        let doctor = Doctor(user: originalUser, code: "D12345", patients: [], hospital: hospital, exerciseGoals: [])
        try hospital.updateAddress("서울시 강남구 중앙로")
        try originalUser.updateName("김가을")
        XCTAssertEqual(doctor.hospital.address, "포항시 남구 중앙로")
        XCTAssertEqual(doctor.user.name, "김하늘")
    }
}
