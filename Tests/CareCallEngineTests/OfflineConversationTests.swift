import Foundation
import Testing
@testable import ToDocCareCall

@MainActor
struct OfflineConversationTests {
    private func analyzer() throws -> OfflineCareCallAnalyzer {
        try OfflineCareCallAnalyzer(config: fixture(CareCallConfig.self, "side_effects"),
                                    bodyParts: fixture(BodyPartDictionary.self, "body_parts"))
    }

    @Test func completesFullInterviewWithoutModelOrFabricatedAnswers() async throws {
        let analyzer = try analyzer()
        let engine = InterviewEngine(config: analyzer.config, rules: try fixture(EmergencyRules.self, "emergency_rules"), analyzer: analyzer)
        _ = engine.start()
        var output = await engine.handle(patientText: "괜찮아요")
        for _ in 0..<40 where !output.isFinished { output = await engine.handle(patientText: "없어요") }
        #expect(output.phase == .saved)
        let converter = SymptomRecordConverter(config: analyzer.config, bodyParts: analyzer.bodyParts)
        let record = converter.record(from: engine.ledger, patientId: UUID(), date: Date(), followUp: false)
        #expect(record.symptoms.count >= 7)
        #expect(record.symptoms.allSatisfy { $0.presence != .present })
    }

    @Test func preservesPositiveNegativeAndUncertainAnswers() async throws {
        let analyzer = try analyzer()
        func request(_ text: String, key: String? = nil) -> AnalysisRequest {
            .init(patientText: text, slotKey: key, slotName: nil, step: key == nil ? nil : .presence, question: "", ledgerSummary: "")
        }
        let positive = try await analyzer.analyze(request("어제부터 입맛이 없어요"))
        #expect(positive.mentions.contains { $0.effectId == "dehydration_nutrition" && $0.presence == .present })
        let negative = try await analyzer.analyze(request("설사는 없어요", key: "diarrhea"))
        #expect(negative.mentions.contains { $0.effectId == "diarrhea" && $0.presence == .absent })
        let unclear = try await analyzer.analyze(request("정확히 기억나지 않아요", key: "diarrhea"))
        #expect(unclear.mentions.contains { $0.effectId == "diarrhea" && $0.presence == .unclear })
        #expect(unclear.mentions.first?.quote == "정확히 기억나지 않아요")
    }
}
