import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 시연 목데이터: 10/16~11/19 매일 증상, 주 2~3회 통증(6~9점 → 4점 이상 낮아짐), 진료 전 기록 2건
struct DemoMockDataTests {
    let patient = UUID()

    @Test func 매일_증상_일곱_항목과_첫날_아침은_모두_없음() throws {
        let data = try DemoMockData(patientId: patient)
        let calendar = DemoMockData.calendar
        #expect(data.symptoms.count == 35)
        #expect(Set(data.symptoms.map { calendar.startOfDay(for: $0.recordedDate) }).count == 35)
        for record in data.symptoms { #expect(Set(record.symptoms.map(\.symptomType)).count == 7) }
        let first = data.symptoms[0]
        #expect(calendar.component(.hour, from: first.recordedDate) == 8)
        #expect(first.symptoms.allSatisfy { $0.presence == .absent })
        #expect(data.symptoms.contains { $0.symptoms.contains { $0.symptomType == .diarrhea && $0.occurrenceCount == 4 } })
    }

    @Test func 통증은_주_2_3회_먹기_전_6_9점에서_4점_이상_낮아진다() throws {
        let data = try DemoMockData(patientId: patient)
        let calendar = DemoMockData.calendar
        let (start, end) = DemoMockData.range
        #expect(data.pain.allSatisfy { $0.recordedDate >= start && $0.recordedDate < end })
        #expect(data.pain.allSatisfy { (6...9).contains($0.painBefore) && ($0.painAfter ?? -1) >= 0 })
        #expect(data.pain.allSatisfy { $0.painBefore - ($0.painAfter ?? 99) >= 4 })
        let weeks = Dictionary(grouping: data.pain) { calendar.dateComponents([.day], from: start, to: $0.recordedDate).day! / 7 }
        #expect(weeks.count == 5 && weeks.values.allSatisfy { (2...3).contains($0.count) })
    }

    @Test func 진료_전_기록은_고정_id_두_건이고_매번_같은_기록이_나온다() throws {
        let a = try DemoMockData(patientId: patient), b = try DemoMockData(patientId: patient)
        #expect(a.previsits.map(\.id) == b.previsits.map(\.id) && a.previsits.count == 2)
        #expect(a.pain.map(\.recordedDate) == b.pain.map(\.recordedDate) && a.pain.map(\.painBefore) == b.pain.map(\.painBefore))
        #expect(a.symptoms.map(\.recordedDate) == b.symptoms.map(\.recordedDate))
    }
}
