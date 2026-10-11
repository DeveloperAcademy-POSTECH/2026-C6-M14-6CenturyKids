nonisolated public enum AddressValidationError: Error, Equatable, Sendable {
    case empty
    case tooLong
    case tooShort
    case invalidCharacter
}
