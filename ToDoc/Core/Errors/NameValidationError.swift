nonisolated public enum NameValidationError: Error, Equatable, Sendable {
    case empty
    case tooLong
    case invalidCharacter
}
