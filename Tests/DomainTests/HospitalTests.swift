import Foundation
import XCTest
import ToDocCoreErrors
import ToDocDomain

final class HospitalTests: XCTestCase {
    private func hospital(name: String = "토닥 병원", address: String = "포항시 남구 중앙로") throws -> Hospital {
        // 병원 Model에는 의사 배열을 넣지 않습니다. 의사 쪽 hospitalId로 관계를 연결합니다.
        try Hospital(id: UUID(), name: name, code: "H12345", address: address, latitude: nil, longitude: nil)
    }
    func testHospitalNameUsesThirtyCharacterLimitAndSharedError() throws {
        XCTAssertEqual(try hospital(name: "  토닥 병원  ").name, "토닥 병원")
        XCTAssertEqual(try hospital(name: String(repeating: "가", count: 30)).name.count, 30)
        for (name, expected) in [(" ", NameValidationError.empty),
                                (String(repeating: "가", count: 31), .tooLong), ("토닥\n병원", .invalidCharacter)] {
            XCTAssertThrowsError(try hospital(name: name)) { XCTAssertEqual($0 as? NameValidationError, expected) }
        }
    }
    func testAddressBoundsApplyToCreationAndUpdatesWithoutLosingPreviousValue() throws {
        var value = try hospital()
        let id = value.id
        for address in ["  abcde  ", String(repeating: "가", count: 100)] {
            XCTAssertEqual(try hospital(address: address).address, address.trimmingCharacters(in: .whitespacesAndNewlines))
            try value.updateAddress(address)
        }
        let saved = value.address
        for (address, expected) in [(" ", AddressValidationError.empty), ("abcd", .tooShort),
                                   (String(repeating: "가", count: 101), .tooLong), ("포항시\n남구", .invalidCharacter)] {
            XCTAssertThrowsError(try hospital(address: address)) { XCTAssertEqual($0 as? AddressValidationError, expected) }
            XCTAssertThrowsError(try value.updateAddress(address)) { XCTAssertEqual($0 as? AddressValidationError, expected) }
            XCTAssertEqual(value.address, saved)
        }
        XCTAssertEqual(value.id, id)
        XCTAssertEqual(value.name, "토닥 병원")
        XCTAssertEqual(value.code, "H12345")
    }
}
