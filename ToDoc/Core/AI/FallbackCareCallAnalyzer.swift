import Foundation

/// Prefer the on-device model, while preserving a complete offline path when it
/// is unavailable or a generation fails. A valid empty result is not a failure.
final class FallbackCareCallAnalyzer: CareCallAI {
    private let primary: (any CareCallAI)?
    private let fallback: any CareCallAI

    init(primary: (any CareCallAI)?, fallback: any CareCallAI) {
        self.primary = primary
        self.fallback = fallback
    }

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        try Task.checkCancellation()
        if let primary {
            do {
                let result = try await primary.analyze(request)
                try Task.checkCancellation()
                return result
            } catch {
                // Leaving the conversation must not start a second analysis.
                try Task.checkCancellation()
                if error is CancellationError { throw error }
            }
        }
        return try await fallback.analyze(request)
    }

    func prewarm() async {
        await primary?.prewarm()
    }

    func speculate(_ request: AnalysisRequest) async {
        guard !Task.isCancelled else { return }
        await primary?.speculate(request)
    }

    @discardableResult func cancelSpeculation() async -> Bool {
        await primary?.cancelSpeculation() ?? false
    }
}
