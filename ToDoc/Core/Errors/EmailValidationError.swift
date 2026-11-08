nonisolated public enum EmailValidationError: Error, Equatable, Sendable {
    case empty
    case invalidFormat
}
