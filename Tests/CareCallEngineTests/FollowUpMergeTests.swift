import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 다시 거는 통화의 기록을 그날 기록에 더하는 규칙 (덮어쓰지 않는다). 가상 기록만
@MainActor
struct FollowUpMergeTests {
    let patientId = UUID()

    private func entry(_ type: SymptomType, _ presence: SymptomPresence, _ detail: String? = nil, part: BodyPart? = nil,
                       count: Int? = nil, minutes: Int? = nil) -> SymptomEntry {
        try! SymptomEntry(id: UUID(), symptomType: type, presence: presence, bodyPart: part, bodySide: nil,
                          rawLocationText: part.map { "\($0)" }, durationMinutes: minutes, occurrenceCount: count, detail: detail)
    }

    private func record(_ entries: [SymptomEntry], at time: TimeInterval = 1_000) -> SymptomRecord {
        SymptomRecord(id: UUID(), patientId: patientId, recordedDate: Date(timeIntervalSince1970: time),
                      conditionText: time == 1_000 ? "그럭저럭이요" : nil, symptoms: entries)
    }

    @Test func 기록_id와_날짜_컨디션은_그날_기록_것() {
        let old = record([entry(.diarrhea, .absent)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .present)], at: 9_000))
        #expect(merged.id == old.id && merged.recordedDate == old.recordedDate)
        #expect(merged.patientId == patientId && merged.conditionText == "그럭저럭이요") // 다시 거는 통화는 컨디션이 없다
    }

    @Test func 그날_기록에_없던_증상은_추가하고_목록_순서로() {
        let old = record([entry(.diarrhea, .absent)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.rashItching, .absent), entry(.nauseaVomiting, .present)]))
        #expect(merged.symptoms.map(\.symptomType) == [.nauseaVomiting, .diarrhea, .rashItching])
    }

    @Test func 없음_모름이던_증상이_이번에_있음이면_이번_항목으로_바꾼다() {
        let old = record([entry(.diarrhea, .absent, "[검토 필요] 환자가 요약에서 지움"), entry(.constipation, .unknown)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .present, "세 번이요", count: 3),
                                                               entry(.constipation, .present)]))
        #expect(merged.symptoms.map(\.presence) == [.present, .present])
        #expect(merged.symptoms.first { $0.symptomType == .diarrhea }?.occurrenceCount == 3)
        #expect(merged.symptoms.first { $0.symptomType == .diarrhea }?.detail == "세 번이요")
    }

    @Test func 전에도_있던_증상은_기존_값을_두고_빈_칸만_채우고_내용을_덧붙인다() {
        let kept = entry(.nauseaVomiting, .present, "구토 횟수: 두 번", count: 2)
        let empty = entry(.diarrhea, .present, "많이요")
        let old = record([kept, empty])
        let merged = CareCallViewModel.merge(old, with: record([entry(.nauseaVomiting, .present, "구토 횟수: 세 번", count: 3),
                                                               entry(.diarrhea, .present, "네 번이요", count: 4)]))
        let vomiting = merged.symptoms[0], diarrhea = merged.symptoms[1]
        #expect(vomiting.id == kept.id && vomiting.occurrenceCount == 2) // 기존 값을 바꾸지 않는다
        #expect(vomiting.detail == "구토 횟수: 두 번 / 다시 통화: 구토 횟수: 세 번")
        #expect(diarrhea.occurrenceCount == 4) // 비어 있던 횟수는 채운다
        #expect(diarrhea.detail == "많이요 / 다시 통화: 네 번이요")
        #expect(merged.symptoms.count == 2)
    }

    @Test func 다른_부위면_항목을_추가하고_부위를_말하지_않았으면_같은_증상으로() {
        let hand = entry(.numbness, .present, "손이요", part: .armHand)
        let old = record([hand])
        let foot = CareCallViewModel.merge(old, with: record([entry(.numbness, .present, "발이요", part: .legFoot)]))
        #expect(foot.symptoms.map(\.bodyPart) == [.armHand, .legFoot])
        let unsaid = CareCallViewModel.merge(old, with: record([entry(.numbness, .present, "또 저렸어요", minutes: 30)]))
        #expect(unsaid.symptoms.count == 1)
        #expect(unsaid.symptoms[0].durationMinutes == 30 && unsaid.symptoms[0].detail == "손이요 / 다시 통화: 또 저렸어요")
    }

    @Test func 이번에_없음_모름이어도_그날_기록에_있던_증상은_그대로() {
        let present = entry(.diarrhea, .present, "세 번")
        let old = record([present])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .absent)]))
        #expect(merged.symptoms.map(\.id) == [present.id] && merged.symptoms[0].presence == .present)
    }

    @Test func 기타_증상은_늘_추가한다() {
        let old = record([entry(.other, .present, "두통: 아침")])
        let merged = CareCallViewModel.merge(old, with: record([entry(.other, .unknown, "[검토 필요] 달라진 점: 글쎄요")]))
        #expect(merged.symptoms.map(\.detail) == ["두통: 아침", "[검토 필요] 달라진 점: 글쎄요"])
    }

    @Test func 검토_필요는_맨_앞에_하나만_두고_길면_자른다() {
        let old = record([entry(.diarrhea, .present, "세 번")])
        let flagged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .present, "[검토 필요] 모르겠어요")]))
        #expect(flagged.symptoms[0].detail == "[검토 필요] 세 번 / 다시 통화: 모르겠어요")
        let long = String(repeating: "가", count: 290)
        let cut = CareCallViewModel.merge(record([entry(.diarrhea, .present, long)]), with: record([entry(.diarrhea, .present, "추가")]))
        #expect(cut.symptoms[0].detail?.count == SymptomEntry.detailLimit)
    }
}
