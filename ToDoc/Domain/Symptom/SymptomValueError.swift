nonisolated public enum SymptomValueError: Error, Equatable, Sendable {
    case invalidDuration
    case invalidOccurrenceCount
    case detailTooLong
}
