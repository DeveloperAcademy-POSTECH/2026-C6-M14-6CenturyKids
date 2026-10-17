import Foundation
import Testing
import ToDocDomain
@testable import ToDocFeatures

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
        #expect(merged.symptoms.first { $0.symptomType == .diarrhea }?.detail == "[검토 필요] 세 번이요 / 전 통화: 환자가 요약에서 지움")
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

    @Test func 전에_있던_증상을_이번에_없다고_하면_값은_두고_그_말을_덧붙인다() {
        let present = entry(.diarrhea, .present, "세 번", count: 3)
        let merged = CareCallViewModel.merge(record([present]), with: record([entry(.diarrhea, .absent)]))
        #expect(merged.symptoms.map(\.id) == [present.id])
        #expect(merged.symptoms[0].presence == .present && merged.symptoms[0].occurrenceCount == 3)
        #expect(merged.symptoms[0].detail == "세 번 / 다시 통화: 지금은 없다고 함")
    }

    @Test func 이번에_모름이거나_전에도_없던_증상은_그대로() {
        let present = entry(.diarrhea, .present, "세 번")
        let absent = entry(.constipation, .absent)
        let merged = CareCallViewModel.merge(record([present, absent]),
                                             with: record([entry(.diarrhea, .unknown), entry(.constipation, .absent)]))
        #expect(merged.symptoms.first { $0.symptomType == .diarrhea }?.detail == "세 번")
        #expect(merged.symptoms.first { $0.symptomType == .constipation }?.detail == nil)
        #expect(merged.symptoms.map(\.presence) == [.absent, .present]) // 목록 순서: 변비, 설사
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

    @Test func 길어도_이번_답은_잘리지_않고_전_내용을_줄인다() {
        let long = String(repeating: "가", count: 295)
        let merged = CareCallViewModel.merge(record([entry(.diarrhea, .present, long)]),
                                             with: record([entry(.diarrhea, .present, "오늘 오후에 네 번이요")]))
        let detail = merged.symptoms[0].detail ?? ""
        #expect(detail.count <= SymptomEntry.detailLimit)
        #expect(detail.hasSuffix("다시 통화: 오늘 오후에 네 번이요"))
    }

    @Test func 요약에서_지운_증상의_검토_필요는_그날_기록에_남긴다() {
        let old = record([entry(.diarrhea, .present, "세 번", count: 3)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .absent, "[검토 필요] 환자가 요약에서 지움: 또 했어요")]))
        #expect(merged.symptoms[0].presence == .present && merged.symptoms[0].occurrenceCount == 3)
        #expect(merged.symptoms[0].detail == "[검토 필요] 세 번 / 다시 통화: 환자가 요약에서 지움: 또 했어요")
    }

    @Test func 이번_답이_아주_길어도_전_내용을_반은_남기고_잘렸으면_검토_필요() {
        let old = String(repeating: "가", count: 200), new = String(repeating: "나", count: 300)
        let merged = CareCallViewModel.merge(record([entry(.diarrhea, .present, old)]), with: record([entry(.diarrhea, .present, new)]))
        let detail = merged.symptoms[0].detail ?? ""
        #expect(detail.count <= SymptomEntry.detailLimit)
        #expect(detail.hasPrefix("[검토 필요] 가"))
        #expect(detail.filter { $0 == "가" }.count >= (SymptomEntry.detailLimit - 20) / 2 - 10)
        #expect(detail.contains("다시 통화: 나"))
    }

    @Test func 없음을_있음으로_바꿀_때_전_통화의_검토_메모를_남긴다() {
        let old = record([entry(.diarrhea, .absent, "[검토 필요] 환자가 요약에서 지움: 세 번")])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .present, "네 번이요", count: 4)]))
        #expect(merged.symptoms.count == 1 && merged.symptoms[0].presence == .present && merged.symptoms[0].occurrenceCount == 4)
        #expect(merged.symptoms[0].detail == "[검토 필요] 네 번이요 / 전 통화: 환자가 요약에서 지움: 세 번")
    }

    @Test func 없어졌다는_말은_그_증상의_모든_부위에_남긴다() {
        let old = record([entry(.numbness, .present, "손이요", part: .armHand), entry(.numbness, .present, "발이요", part: .legFoot)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.numbness, .absent)]))
        #expect(merged.symptoms.map(\.detail) == ["손이요 / 다시 통화: 지금은 없다고 함", "발이요 / 다시 통화: 지금은 없다고 함"])
    }

    @Test func 없음을_있음으로_바꿀_때_전_통화의_값은_가져오지_않고_내용만_남긴다() {
        let old = record([entry(.diarrhea, .unknown, "[검토 필요] 모르겠어요", count: 2, minutes: 30)])
        let merged = CareCallViewModel.merge(old, with: record([entry(.diarrhea, .present, "많이요")]))
        #expect(merged.symptoms[0].occurrenceCount == nil && merged.symptoms[0].durationMinutes == nil) // 이번 답의 값만
        #expect(merged.symptoms[0].detail == "[검토 필요] 많이요 / 전 통화: 모르겠어요")
    }
}
