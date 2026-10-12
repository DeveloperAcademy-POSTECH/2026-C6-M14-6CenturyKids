import XCTest
@testable import AuthPresentation

final class AuthFormValidationTests: XCTestCase {
    func testEmailRequiresLocalAndDomainAndTrimsOnlyEdges() {
        XCTAssertNil(AuthFormValidation.emailError("  patient@example.com\n"))
        for value in ["", "patient", "@example.com", "p@", "p a@example.com", "p@example..com"] {
            XCTAssertNotNil(AuthFormValidation.emailError(value), value)
        }
    }

    func testNameUsesTenCharactersAndAllowsInternationalNames() {
        XCTAssertNil(AuthFormValidation.nameError("  김하늘  "))
        XCTAssertNil(AuthFormValidation.nameError("Jean-Luc"))
        XCTAssertNotNil(AuthFormValidation.nameError("  \n"))
        XCTAssertNotNil(AuthFormValidation.nameError(String(repeating: "가", count: 11)))
        XCTAssertNotNil(AuthFormValidation.nameError("김\n하늘"))
    }

    func testSignupPasswordRequiresLettersDigitsAndEightCharacters() {
        XCTAssertNil(AuthFormValidation.passwordError("abc12345"))
        XCTAssertNil(AuthFormValidation.passwordError(" abc1234 "))
        for value in ["", "abc123", "abcdefgh", "12345678"] {
            XCTAssertNotNil(AuthFormValidation.passwordError(value))
        }
    }
}
