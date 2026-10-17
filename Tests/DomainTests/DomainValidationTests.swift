import XCTest
import ToDocCoreErrors
@testable import ToDocDomain

/// 예전 UserTests의 이메일 사례를 기존 검증 함수의 테스트로 옮겼습니다.
/// 현재 User에는 email 속성이 없으므로 User가 이메일을 검증한다고 가정하지 않습니다.
/// 이 테스트는 DomainValidation.email만 확인하며 인증 화면/서버의 검증을 대신하지 않습니다.
final class DomainValidationTests: XCTestCase {
    func testEmailRejectsMalformedAddressesAndTrimsEdges() throws {
        XCTAssertEqual(try DomainValidation.email("  p+tag@example.com\n"), "p+tag@example.com")
        XCTAssertThrowsError(try DomainValidation.email("  ")) { XCTAssertEqual($0 as? EmailValidationError, .empty) }
        for email in ["p", "@example.com", "p@", "p a@example.com", "p@example..com", ".p@example.com", "p.@example.com"] {
            XCTAssertThrowsError(try DomainValidation.email(email)) { XCTAssertEqual($0 as? EmailValidationError, .invalidFormat) }
        }
    }
}
