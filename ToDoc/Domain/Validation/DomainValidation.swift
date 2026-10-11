import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

nonisolated enum DomainValidation {
    static func name(_ rawValue: String, maximum: Int) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw NameValidationError.empty }
        guard value.count <= maximum else { throw NameValidationError.tooLong }
        guard value.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw NameValidationError.invalidCharacter
        }
        return value
    }

    static func email(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw EmailValidationError.empty }
        let pattern = #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#
        guard value.range(of: pattern, options: .regularExpression) != nil,
              !value.hasPrefix("."), !value.contains(".."), !value.contains(".@") else {
            throw EmailValidationError.invalidFormat
        }
        return value
    }
}
