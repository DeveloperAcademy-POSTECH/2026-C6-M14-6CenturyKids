import Foundation
import Testing
import ToDocDomain
@testable import ToDocCareCall

/// 통화 기록(Ledger) → 저장할 증상 기록 (#84 저장 규칙). 가상 발화만
struct SymptomRecordConverterTests {
    let config = try! fixture(CareCallConfig.self, "side_effects")
    let converter: SymptomRecordConverter
    let ids: Set<String>
    let date = Date(timeIntervalSince1970: 1_000)
    let patientId = UUID()

    init() throws {
        converter = SymptomRecordConverter(config: config, bodyParts: try fixture(BodyPartDictionary.self, "body_parts"))
        ids = Set(config.effects.map(\.id))
    }

    private func said(_ ledger: inout Ledger, _ id: String, _ presence: MentionPresence, _ text: String, locations: [String] = []) {
        ledger.apply(Mention(effectId: id, presence: presence, locations: locations, quote: text), patientText: text, knownEffectIds: ids)
    }

    private func label(_ id: String) -> String { config.effects.first { $0.id == id }!.details[0].label }

    @Test func 없음과_모름도_답으로_저장한다() {
        var ledger = Ledger()
        said(&ledger, "nausea_vomiting", .present, "네 토했어요")
        said(&ledger, "constipation", .absent, "없어요")
        _ = ledger.markAsked("diarrhea", step: .presence)
        ledger.markUnknown("diarrhea", step: .presence, quote: "잘 모르겠어요")
        let record = converter.record(from: ledger, patientId: patientId, date: date)
        #expect(record.recordedDate == date)
        #expect(record.symptoms.map(\.symptomType) == [.nauseaVomiting, .constipation, .diarrhea])
        #expect(record.symptoms.map(\.presence) == [.present, .absent, .unknown])
        #expect(record.symptoms.map(\.detail) == [nil, nil, "[검토 필요] 잘 모르겠어요"])
    }

    @Test func 끊기면_답한_곳까지만() {
        var ledger = Ledger()
        said(&ledger, "nausea_vomiting", .present, "네 토했어요")
        _ = ledger.markAsked("constipation", step: .presence) // 묻는 중에 끊김
        #expect(converter.record(from: ledger, patientId: patientId, date: date).symptoms.map(\.symptomType) == [.nauseaVomiting])
    }

    @Test func 끝까지_물어도_답이_없으면_모름() {
        var ledger = Ledger()
        for _ in 0...Ledger.maxFollowUps { _ = ledger.markAsked("constipation", step: .presence) }
        let askedAgain = ledger.markAsked("constipation", step: .presence) // 꼬리질문 한도를 넘어 닫힘
        #expect(!askedAgain)
        let entry = converter.record(from: ledger, patientId: patientId, date: date).symptoms.first
        #expect(entry?.presence == .unknown)
        #expect(entry?.detail == "[검토 필요]")
    }

    @Test func 횟수는_횟수_질문의_답에서만_읽는다() {
        var ledger = Ledger()
        said(&ledger, "diarrhea", .present, "네 했어요")
        ledger.addDetail("하루 세 번이요", label: label("diarrhea"), for: "diarrhea")
        said(&ledger, "constipation", .present, "네 있어요")
        ledger.addDetail("세 번째 날이에요 두 시간 전부터요", label: label("constipation"), for: "constipation")
        let symptoms = converter.record(from: ledger, patientId: patientId, date: date).symptoms
        #expect(symptoms.map(\.occurrenceCount) == [3, nil])
        #expect(symptoms.map(\.durationMinutes) == [nil, nil]) // "언제부터"의 답은 지속 시간이 아니다
        #expect(symptoms.map(\.detail) == ["하루 세 번이요", "세 번째 날이에요 두 시간 전부터요"])
    }

    @Test func 지속_시간은_분으로_읽고_모호하면_말만_남긴다() {
        var ledger = Ledger()
        said(&ledger, "neuropathy", .present, "네 저려요", locations: [])
        ledger.addDetail("한 시간 반쯤 가요", label: label("neuropathy"), for: "neuropathy")
        said(&ledger, "rash_pruritus", .present, "네 가려워요")
        ledger.addDetail("이삼십 분이요", label: label("rash_pruritus"), for: "rash_pruritus")
        let symptoms = converter.record(from: ledger, patientId: patientId, date: date).symptoms
        #expect(symptoms.map(\.durationMinutes) == [90, nil])
        #expect(symptoms.map(\.detail) == ["한 시간 반쯤 가요", "이삼십 분이요"])
    }

    @Test func 부위가_여럿이면_부위별로_나누고_빠진_좌우는_환자_말에서_찾는다() {
        var ledger = Ledger()
        said(&ledger, "neuropathy", .present, "네 저려요")
        ledger.addDetail("삼십 분쯤이요", label: label("neuropathy"), for: "neuropathy")
        said(&ledger, "neuropathy", .present, "양쪽 발이랑 왼손이요", locations: ["발", "왼손"])
        let symptoms = converter.record(from: ledger, patientId: patientId, date: date).symptoms
        #expect(symptoms.map(\.bodyPart) == [.legFoot, .armHand])
        #expect(symptoms.map(\.bodySide) == [.both, .left])
        #expect(symptoms.map(\.rawLocationText) == ["양쪽 발", "왼손"])
        #expect(symptoms.map(\.durationMinutes) == [30, 30])
    }

    @Test func 좌우를_붙여_같아진_부위는_한_번만() {
        var ledger = Ledger()
        said(&ledger, "neuropathy", .present, "양쪽 발이요", locations: ["발", "양쪽 발"])
        #expect(converter.record(from: ledger, patientId: patientId, date: date).symptoms.map(\.rawLocationText) == ["양쪽 발"])
    }

    @Test(arguments: [
        ("왼손이 저려요", "손", "왼손", BodySide?.some(.left)), ("오른쪽 발이요", "발", "오른쪽 발", .right),
        ("양말 신으면 발이 저려요", "발", "발", nil), ("손이요", "손", "손", nil),
    ])
    func 좌우는_환자가_말한_대로(text: String, word: String, raw: String, side: BodySide?) {
        var ledger = Ledger()
        said(&ledger, "neuropathy", .present, text, locations: [word])
        let entry = converter.record(from: ledger, patientId: patientId, date: date).symptoms.first
        #expect(entry?.rawLocationText == raw)
        #expect(entry?.bodySide == side)
    }

    @Test func 부위를_묻지_않는_항목의_부위와_사전에_없는_부위() {
        var ledger = Ledger()
        said(&ledger, "dehydration_nutrition", .present, "물을 잘 못 마셔요", locations: ["물"])
        said(&ledger, "rash_pruritus", .present, "온몸이 가려워요", locations: ["온몸"])
        let symptoms = converter.record(from: ledger, patientId: patientId, date: date).symptoms
        #expect(symptoms.map(\.rawLocationText) == [nil, "온몸"])
        #expect(symptoms.map(\.bodyPart) == [nil, nil])
    }

    @Test func 기타_증상은_이름을_붙이고_검토_필요를_표시한다() {
        var ledger = Ledger()
        ledger.apply(Mention(effectId: "other", otherName: "어지러움", presence: .present, quote: "어지러워요"),
                     patientText: "어지러워요", knownEffectIds: ids)
        ledger.addDetail("아침에 잠깐요", label: config.otherDetail.label, for: "other:어지러움")
        ledger.markNeedsReview("other:어지러움")
        let entry = converter.record(from: ledger, patientId: patientId, date: date).symptoms.first
        #expect(entry?.symptomType == .other)
        #expect(entry?.detail == "[검토 필요] 어지러움: 어지러워요 / 아침에 잠깐요") // 처음 말한 문장도
    }

    @Test func 모델이_이름을_못_뽑은_기타_증상은_문장을_한_번만() {
        var ledger = Ledger()
        ledger.apply(Mention(effectId: "other", otherName: "잠을 잘 못 자요", presence: .present, quote: "잠을 잘 못 자요."),
                     patientText: "잠을 잘 못 자요.", knownEffectIds: ids)
        #expect(converter.record(from: ledger, patientId: patientId, date: date).symptoms.first?.detail == "잠을 잘 못 자요")
    }


    @Test func 답이_길어도_항목을_잃지_않는다() {
        var ledger = Ledger()
        said(&ledger, "diarrhea", .present, "네")
        ledger.addDetail(String(repeating: "하루 세 번이요 ", count: 40), label: label("diarrhea"), for: "diarrhea")
        ledger.markNeedsReview("diarrhea")
        let entry = converter.record(from: ledger, patientId: patientId, date: date).symptoms.first
        #expect(entry?.detail?.count == SymptomEntry.detailLimit)
        #expect(entry?.detail?.hasPrefix("[검토 필요] 하루 세 번이요") == true)
        #expect(entry?.occurrenceCount == 3)
    }

    @Test func 횟수와_지속_시간을_읽는_항목() {
        let reads = { (n: CareCallConfig.Effect.Detail.Number) in config.effects.filter { $0.details.contains { $0.number == n } }.map(\.id) }
        #expect(reads(.count) == ["nausea_vomiting", "diarrhea"])
        #expect(reads(.minutes) == ["neuropathy", "rash_pruritus"])
    }

    @Test func 구토와_메스꺼움을_둘_다_답하면_이름을_붙여_한_항목에() {
        var ledger = Ledger()
        said(&ledger, "nausea_vomiting", .present, "네")
        ledger.addDetail("하루 두 번이요", label: "구토 횟수", for: "nausea_vomiting")
        ledger.addDetail("어제부터요", label: "메스꺼움 시작", for: "nausea_vomiting")
        let entry = converter.record(from: ledger, patientId: patientId, date: date).symptoms.first
        #expect(entry?.detail == "구토 횟수: 하루 두 번이요 / 메스꺼움 시작: 어제부터요")
        #expect(entry?.occurrenceCount == 2)
    }

    @Test func 환자와_첫_질문_답을_기록에_넣는다() {
        var ledger = Ledger()
        ledger.setConditionText("그럭저럭이요 / 어제 좀 토했어요")
        let record = converter.record(from: ledger, patientId: patientId, date: date)
        #expect(record.patientId == patientId)
        #expect(record.conditionText == "그럭저럭이요 / 어제 좀 토했어요")
        #expect(converter.record(from: Ledger(), patientId: patientId, date: date).conditionText == nil) // 첫 질문 전
    }

    @Test func 그날_기록에_없는_항목을_다시_거는_통화에서_이어_묻는다() throws {
        let answered = try [SymptomType.nauseaVomiting, .diarrhea, .other].map {
            try SymptomEntry(id: UUID(), symptomType: $0, presence: .absent, bodyPart: nil, bodySide: nil,
                             durationMinutes: nil, occurrenceCount: nil, detail: nil)
        }
        let record = SymptomRecord(id: UUID(), patientId: patientId, recordedDate: date, conditionText: nil, symptoms: answered)
        #expect(converter.unasked(in: record) == ["constipation", "stomatitis", "neuropathy", "rash_pruritus", "dehydration_nutrition"])
        #expect(converter.unasked(in: SymptomRecord(id: UUID(), patientId: patientId, recordedDate: date, conditionText: nil, symptoms: [])).count == config.effects.count)
    }
}
