//
//  SymptomRecordConverter.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif
import Foundation

/// 통화 기록(Ledger)을 저장할 증상 기록으로 바꾼다 (#84 저장 규칙).
/// 값이 Domain 검증에 걸려도 그 항목이나 그날 기록 전체를 잃지 않게, 환자 말은 길이를 맞추고 숫자는 검증에 걸리면 뺀다.
struct SymptomRecordConverter {
    /// side_effects.json의 항목 ID → Domain 증상 종류
    private static let types: [String: SymptomType] = [
        "nausea_vomiting": .nauseaVomiting, "constipation": .constipation, "diarrhea": .diarrhea,
        "stomatitis": .oralPain, "neuropathy": .numbness, "rash_pruritus": .rashItching,
        "dehydration_nutrition": .dehydrationNutrition,
    ]

    let config: CareCallConfig
    let bodyParts: BodyPartDictionary

    /// 첫 질문 답(ledger.conditionText)은 컨디션으로 그대로 넣는다 (첫 질문에 답하기 전이면 nil).
    /// 통화가 끊겼으면 끊긴 곳까지. 묻는 중이라 아직 답이 없는 항목은 넣지 않는다
    /// (끝까지 물어도 답이 분명하지 않아 닫힌 항목은 '모름')
    /// followUp: 같은 날 다시 거는 통화. 묻지 않았는데 없어졌다고 말한 증상은 그 말을 내용으로 남긴다
    /// ("구토가 나아졌어요" → 그날 기록에 "다시 통화: 구토가 나아졌어요"로 더한다)
    func record(from ledger: Ledger, patientId: UUID, date: Date, followUp: Bool = false) -> SymptomRecord {
        let all = ledger.order.compactMap { ledger[$0] }
        // 한 문장에 여러 증상을 말했으면("구토는 멈췄고 설사를 했어요") 그 문장을 어느 한 증상의 말로 남기지 않는다
        let shared = Set(Dictionary(all.flatMap { Set($0.quotes) }.map { ($0, 1) }, uniquingKeysWith: +).filter { $0.value > 1 }.keys)
        let answered = all.filter { $0.presence != nil || $0.closed }
        let entries = answered.flatMap { entries(for: $0, followUp: followUp, shared: shared) }
        return SymptomRecord(id: UUID(), patientId: patientId, recordedDate: date, conditionText: ledger.conditionText, symptoms: entries)
    }

    /// 그날 기록에 아직 없는 항목 (지난 통화가 끊겨 못 물음). 다시 거는 통화에서 이어서 묻는다
    func unasked(in record: SymptomRecord) -> Set<String> {
        let recorded = Set(record.symptoms.map(\.symptomType))
        return Set(config.effects.map(\.id).filter { id in Self.types[id].map { !recorded.contains($0) } ?? false })
    }

    /// 한 항목 → 부위별 SymptomEntry (부위가 없으면 하나)
    private func entries(for e: Ledger.Entry, followUp: Bool, shared: Set<String>) -> [SymptomEntry] {
        let effect = config.effects.first { $0.id == e.effectId }
        let presence: SymptomPresence = switch e.presence {
        case .present: .present
        case .absent: .absent
        case .unclear, nil: .unknown // 모르겠다고 답했거나, 꼬리질문 끝에도 분명하지 않음
        }
        let answers = e.details.filter { !$0.text.isEmpty }
        let questions = effect?.details ?? []
        // 꼬리질문이 둘인 항목은 어느 질문의 답인지 이름을 붙인다 ("구토 횟수: 하루 세 번이요 / 메스꺼움 시작: 어제부터요")
        // 기타 증상은 처음 말한 문장도 남긴다. 모델이 이름을 못 뽑아 그 문장이 이름이면 한 번만
        let firstSaid = e.effectId == "other" ? e.quotes.first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .flatMap { said in said.isEmpty || e.otherName?.contains(said) == true ? nil : said } : nil
        // 다시 거는 통화에서 묻지 않았는데 없어졌다고 한 말 ("구토가 나아졌어요"). 물어서 "아니요"라고 한 답과
        // 다른 증상도 함께 말한 문장은 남기지 않는다 (그날 기록에는 "지금은 없다고 함"으로 더한다)
        let toldAbsent = followUp && presence == .absent && answers.isEmpty && !e.askedSteps.contains(.presence)
            ? e.quotes.last.flatMap { shared.contains($0) ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
            : nil
        // 유무 질문에 한 답·모르겠다고 한 답은 원문 그대로 ("숨이 잘 안 쉬어져요", "[검토 필요] … / 부위: 모르겠어요"). 같은 말은 한 번만
        var said: [String] = []
        for part in [firstSaid, toldAbsent].compactMap(\.self) + e.answers + answers.map({ questions.count > 1 ? "\($0.label): \($0.text)" : $0.text })
            + e.unsureAnswers where !said.contains(part) { said.append(part) }
        let answerText = said.joined(separator: " / ")
        // 검토 필요 → 앞에 표시, 기타 증상 → 앞에 이름 (#84)
        let body = [e.otherName, answerText.isEmpty ? nil : answerText].compactMap(\.self).joined(separator: ": ")
        let text = ([e.needsReview ? "[검토 필요]" : nil, body.isEmpty ? nil : body].compactMap(\.self)).joined(separator: " ")
        let detail = text.isEmpty ? nil : String(text.prefix(SymptomEntry.detailLimit))
        // 숫자는 그 숫자를 물은 질문의 답에서만 읽는다 ("언제부터"의 "두 시간 전"을 지속 시간으로 읽지 않게)
        func number(_ kind: CareCallConfig.Effect.Detail.Number, _ read: (String) -> Int?) -> Int? {
            guard presence == .present else { return nil }
            let asked = answers.filter { a in questions.contains { $0.label == a.label && $0.number == kind } }
            return asked.compactMap { read($0.text) }.first
        }
        let count = number(.count, NumberParser.count(in:)), minutes = number(.minutes, NumberParser.minutes(in:))
        // 부위는 부위를 묻는 항목만 ("식사량"에 붙은 "물" 같은 낱말은 버린다)
        // 좌우를 붙이면 같아지는 낱말("발", "양쪽 발")은 한 항목으로
        var seen = Set<String>()
        let spoken = e.locations.map { spokenLocation($0, in: e.quotes) }.filter { seen.insert($0).inserted }
        let locations: [String?] = presence == .present && effect?.requiresLocation == true && !spoken.isEmpty ? spoken : [nil]
        let type = Self.types[e.effectId] ?? .other
        return locations.compactMap { location in
            let part = location.flatMap(bodyParts.bodyPart(for:)), side = location.flatMap(bodyParts.bodySide(for:))
            func entry(count: Int?, minutes: Int?) -> SymptomEntry? {
                try? SymptomEntry(id: UUID(), symptomType: type, presence: presence, bodyPart: part, bodySide: side,
                                  rawLocationText: location, durationMinutes: minutes, occurrenceCount: count, detail: detail)
            }
            // detail은 길이를 맞췄으니 숫자를 빼면 항상 만들어진다
            return entry(count: count, minutes: minutes) ?? entry(count: nil, minutes: nil)
        }
    }

    /// 모델이 좌우를 빼고 낱말만 낸 경우 환자 말에서 좌우를 찾아 붙인다 ("왼손이 저려요" → "왼손", "양쪽 발이요" → "양쪽 발").
    /// 앞 낱말은 "쪽"·"편"이 든 말만 본다 ("양말 신으면 발이"의 "양말"을 양쪽으로 읽지 않게)
    private func spokenLocation(_ word: String, in quotes: [String]) -> String {
        guard bodyParts.bodySide(for: word) == nil else { return word }
        for quote in quotes {
            let tokens = quote.split(whereSeparator: \.isWhitespace).map(String.init)
            for (i, token) in tokens.enumerated() {
                guard let range = token.range(of: word) else { continue }
                let head = String(token[..<range.upperBound])
                if bodyParts.bodySide(for: head) != nil { return head }
                if i > 0, tokens[i - 1].contains(where: { "쪽편".contains($0) }), bodyParts.bodySide(for: tokens[i - 1]) != nil {
                    return tokens[i - 1] + " " + head
                }
            }
        }
        return word
    }
}
