nonisolated enum CareCallPreparationState: Equatable, Sendable {
    case idle
    case preparing(CareCallPreparationPhase)
    case ready
    case microphoneDenied
    case modelMissing
    case modelLoadFailed
    case speechRecognitionUnsupported
    case failed
    case unavailable
}
