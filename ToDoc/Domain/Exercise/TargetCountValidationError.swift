nonisolated public enum TargetCountValidationError: Error, Equatable, Sendable {
    case belowMinimum
    case aboveMaximum
}
