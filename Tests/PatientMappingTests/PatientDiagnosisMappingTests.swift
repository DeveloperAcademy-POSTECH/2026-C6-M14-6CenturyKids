import XCTest
import ToDocDomain
@testable import ToDocPatientMapping

final class PatientDiagnosisMappingTests: XCTestCase {
    private let userID = UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!
    private func user() throws -> User {
        try User(id: userID, name: "테스트", birthday: Date(timeIntervalSince1970: 946684800), sex: .female)
    }
    private func decode(_ fields: [String: Any]) throws -> PatientDTO {
        var json = fields
        json["user_id"] = userID.uuidString
        return try JSONDecoder().decode(PatientDTO.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func encode(_ patient: Patient) throws -> [String: Any] {
        let data = try JSONEncoder().encode(PatientDTO(patient: patient))
        let json = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(json as? [String: Any])
    }

    func testOtherCancerNameAndUnknownStageSurviveDatabaseRoundTrip() throws {
        let dto = try decode(["carcinoma_type": "other", "carcinoma_stage": "unknown", "carcinoma_other_name": " 연부조직 육종 "])
        let patient = try dto.toDomain(user: user())
        XCTAssertEqual(patient.disease?.otherName, "연부조직 육종")
        XCTAssertEqual(patient.disease?.stage, .unknown)
        let encoded = try encode(patient)
        XCTAssertEqual(encoded["carcinoma_type"] as? String, "other")
        XCTAssertEqual(encoded["carcinoma_stage"] as? String, "unknown")
        XCTAssertEqual(encoded["carcinoma_other_name"] as? String, "연부조직 육종")
    }

    func testLegacyKnownCancerWithoutNewColumnStillDecodes() throws {
        let dto = try decode(["carcinoma_type": "lung", "carcinoma_stage": "stage1"])
        let patient = try dto.toDomain(user: user())
        XCTAssertEqual(patient.disease?.carcinoma, .lung)
        XCTAssertEqual(patient.disease?.stage, .stage1)
        XCTAssertNil(patient.disease?.otherName)
    }

    func testSwitchingToKnownCancerExplicitlyClearsStoredFreeText() throws {
        var disease = CarcinomaDetail(carcinoma: .other, stage: .stage2, otherName: "연부조직 육종")
        disease.updateCarcinomaType(.lung)
        let encoded = try encode(Patient(user: user(), doctorId: nil, disease: disease))
        XCTAssertNil(disease.otherName)
        XCTAssertTrue(encoded["carcinoma_other_name"] is NSNull, "upsert에서 키가 빠지면 이전 기타 이름이 남을 수 있습니다.")
    }

    func testOtherCancerWithoutNameIsRejectedInBothDirections() throws {
        for fields: [String: Any] in [
            ["carcinoma_type": "other", "carcinoma_stage": "stage1"],
            ["carcinoma_type": "other", "carcinoma_stage": "unknown", "carcinoma_other_name": " \n "]
        ] {
            let dto = try decode(fields)
            XCTAssertThrowsError(try dto.toDomain(user: user()))
        }
        let patient = Patient(user: try user(), doctorId: nil, disease: .init(carcinoma: .other, stage: .unknown))
        XCTAssertThrowsError(try encode(patient))
    }

    func testUnknownStageIsDistinctFromMissingDiagnosis() throws {
        let unknown = try decode(["carcinoma_type": "breast", "carcinoma_stage": "unknown"]).toDomain(user: user())
        let absent = try decode([:]).toDomain(user: user())
        XCTAssertEqual(unknown.disease?.stage, .unknown)
        XCTAssertNil(absent.disease)
    }
}
