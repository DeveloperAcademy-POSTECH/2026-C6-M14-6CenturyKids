import XCTest
@testable import ToDocAuth

final class AuthPasswordValidationTests: XCTestCase {
    func testPasswordPolicyMatchesAcrossSignupRecoveryAndSettings() {
        let valid = ["Abcdef12", "abcdefghijklmnopqr12", "Abcdef1!"]
        let invalid = ["Abcde12", "abcdefghijklmnopqrs12", "abcdefgh", "12345678", "가나다라마바12", "Abcdefg１"]
        for password in valid {
            XCTAssertNil(AuthFormValidation.passwordError(password), password)
            XCTAssertNil(AuthFormValidation.passwordChangeError(password), password)
        }
        for password in invalid {
            XCTAssertNotNil(AuthFormValidation.passwordError(password), password)
            XCTAssertNotNil(AuthFormValidation.passwordChangeError(password), password)
        }
    }
}
