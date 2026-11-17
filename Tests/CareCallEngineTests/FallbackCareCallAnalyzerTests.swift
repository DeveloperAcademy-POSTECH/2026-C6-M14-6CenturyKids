import Foundation
import Testing
@testable import ToDocCareCall

@MainActor
struct FallbackCareCallAnalyzerTests {
    private let request = AnalysisRequest(patientText: "어제부터 입맛이 없어요", slotKey: "dehydration_nutrition",
                                          slotName: "식사", step: .presence, question: "식사는 어떠세요?", ledgerSummary: "")

    @Test func prefersModelAndPreservesItsResult() async throws {
        let expected = TurnResult(mentions: [.init(effectId: "dehydration_nutrition", presence: .present,
                                                 quote: "어제부터 입맛이 없어요")])
        let primary = AnalyzerStub(result: expected)
        let fallback = AnalyzerStub()
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        #expect(try await analyzer.analyze(request) == expected)
        #expect(primary.requests.count == 1)
        #expect(fallback.requests.isEmpty)
    }

    @Test func validEmptyModelResultDoesNotTriggerFallback() async throws {
        let primary = AnalyzerStub()
        let fallback = AnalyzerStub(error: TestFailure.generation)
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        #expect(try await analyzer.analyze(request).mentions.isEmpty)
        #expect(fallback.requests.isEmpty)
    }

    @Test func unavailableModelUsesOfflineRulesWithOriginalAnswer() async throws {
        let fallback = try OfflineCareCallAnalyzer(config: fixture(CareCallConfig.self, "side_effects"),
                                                   bodyParts: fixture(BodyPartDictionary.self, "body_parts"))
        let analyzer = FallbackCareCallAnalyzer(primary: nil, fallback: fallback)
        let result = try await analyzer.analyze(request)
        #expect(result.mentions.contains { $0.effectId == "dehydration_nutrition" && $0.presence == .present })
        #expect(result.mentions.first?.quote == request.patientText)
    }

    @Test func failedTurnFallsBackButNextTurnTriesModelAgain() async throws {
        let primary = AnalyzerStub(error: TestFailure.generation)
        let fallback = AnalyzerStub(result: .init(mentions: [], needsClarification: true))
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        #expect(try await analyzer.analyze(request).needsClarification)
        #expect(fallback.requests.first?.patientText == request.patientText)
        #expect(fallback.requests.first?.slotKey == request.slotKey)
        #expect(fallback.requests.first?.question == request.question)
        primary.error = nil
        #expect(try await analyzer.analyze(request) == primary.result)
        #expect(primary.requests.count == 2)
        #expect(fallback.requests.count == 1)
    }

    @Test func cancellationDoesNotRunFallback() async throws {
        let primary = AnalyzerStub(error: CancellationError())
        let fallback = AnalyzerStub()
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        await #expect(throws: CancellationError.self) { try await analyzer.analyze(request) }
        #expect(fallback.requests.isEmpty)
    }

    @Test func cancelledCallerRejectsLateModelResult() async throws {
        let primary = AnalyzerStub()
        var release: CheckedContinuation<Void, Never>?
        primary.beforeAnswer = { await withCheckedContinuation { release = $0 } }
        let fallback = AnalyzerStub()
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        let task = Task { try await analyzer.analyze(request) }
        while release == nil { await Task.yield() }
        task.cancel()
        release?.resume()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(fallback.requests.isEmpty)
    }

    @Test func forwardsModelPreparationAndSpeculation() async {
        let primary = AnalyzerStub()
        let fallback = AnalyzerStub()
        let analyzer = FallbackCareCallAnalyzer(primary: primary, fallback: fallback)
        await analyzer.prewarm()
        await analyzer.speculate(request)
        #expect(await analyzer.cancelSpeculation())
        #expect(primary.prewarmCount == 1)
        #expect(primary.speculationCount == 1)
        #expect(primary.cancelCount == 1)
        #expect(fallback.prewarmCount == 0)
        #expect(fallback.speculationCount == 0)
    }

    @Test func fallbackFailureIsPropagated() async throws {
        let analyzer = FallbackCareCallAnalyzer(primary: AnalyzerStub(error: TestFailure.generation),
                                                fallback: AnalyzerStub(error: TestFailure.fallback))
        await #expect(throws: TestFailure.fallback) { try await analyzer.analyze(request) }
    }
}

private enum TestFailure: Error { case generation, fallback }

private final class AnalyzerStub: CareCallAI {
    var result: TurnResult
    var error: (any Error)?
    var beforeAnswer: (() async -> Void)?
    var requests: [AnalysisRequest] = []
    var prewarmCount = 0
    var speculationCount = 0
    var cancelCount = 0

    init(result: TurnResult = .init(mentions: []), error: (any Error)? = nil) {
        self.result = result
        self.error = error
    }

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        requests.append(request)
        await beforeAnswer?()
        if let error { throw error }
        return result
    }

    func prewarm() async { prewarmCount += 1 }
    func speculate(_ request: AnalysisRequest) async { speculationCount += 1 }
    func cancelSpeculation() async -> Bool { cancelCount += 1; return true }
}
