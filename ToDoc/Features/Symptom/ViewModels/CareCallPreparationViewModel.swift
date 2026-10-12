import Foundation
import Observation

@MainActor @Observable
final class CareCallPreparationViewModel {
    typealias Progress = @MainActor @Sendable (CareCallPreparationPhase) -> Void
    typealias Prepare = @MainActor @Sendable (@escaping Progress) async throws -> Void

    private(set) var state: CareCallPreparationState = .idle
    @ObservationIgnored private let operation: Prepare
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var preparationTask: Task<Void, Error>?

    init(prepare: @escaping Prepare = { _ in throw CareCallPreparationError.unavailable }) {
        operation = prepare
    }

    var isPreparing: Bool {
        if case .preparing = state { return true }
        return false
    }

    var canStart: Bool { state == .ready }

    func prepare() async {
        guard !Task.isCancelled, !isPreparing, !canStart else { return }
        let id = UUID()
        requestID = id
        state = .preparing(.permissions)
        let task = Task { [operation, weak self] in
            try Task.checkCancellation()
            try await operation { [weak self] phase in
                guard let self, self.requestID == id, self.isPreparing else { return }
                self.state = .preparing(phase)
            }
        }
        preparationTask = task
        defer { if requestID == id { preparationTask = nil } }
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard requestID == id else { return }
            state = Task.isCancelled ? .idle : .ready
        } catch {
            guard requestID == id else { return }
            if Task.isCancelled || error is CancellationError {
                state = .idle
            } else {
                switch error {
                case CareCallPreparationError.microphoneDenied: state = .microphoneDenied
                case CareCallPreparationError.modelMissing: state = .modelMissing
                case CareCallPreparationError.modelLoadFailed: state = .modelLoadFailed
                case CareCallPreparationError.speechRecognitionUnsupported: state = .speechRecognitionUnsupported
                case CareCallPreparationError.unavailable: state = .unavailable
                default: state = .failed
                }
            }
        }
    }

    /// 취소 신호를 전달합니다. SDK 자원 정리는 주입한 작업이 담당합니다.
    func cancel() {
        requestID = UUID()
        preparationTask?.cancel()
        preparationTask = nil
        state = .idle
    }
}
