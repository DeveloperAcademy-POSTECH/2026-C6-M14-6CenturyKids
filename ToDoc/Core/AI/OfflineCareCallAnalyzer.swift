import Foundation

/// Uses only the bundled vocabulary. Ambiguous answers remain unknown with the original text;
/// this records the participant's answers, and never generates a diagnosis or a fabricated answer.
struct OfflineCareCallAnalyzer: CareCallAI {
    let config: CareCallConfig
    let bodyParts: BodyPartDictionary

    func analyze(_ request: AnalysisRequest) async throws -> TurnResult {
        let text = request.patientText.trimmingCharacters(in: .whitespacesAndNewlines)
        let reading = AnswerReading(config: config,
                                    symptomHints: KeywordMatcher(keywords: config.symptomHints, prefixNegation: true),
                                    openingConcerns: KeywordMatcher(keywords: config.openingConcerns, prefixNegation: true),
                                    locationWords: bodyParts.parts.values.flatMap { $0 })
        var mentions: [Mention] = []
        for effect in config.effects {
            let clauses = AnswerReading.parts(text).filter { clause in
                effect.keywords.contains(where: clause.contains) || reading.saysPresent(effect, clause)
            }
            guard !clauses.isEmpty else { continue }
            let positive = clauses.first { reading.saysPresent(effect, $0) ||
                (!reading.soundsNegative($0) && !reading.saysFine($0, for: effect) && effect.affirmed(in: $0)) }
            let negative = clauses.first { reading.saysFine($0, for: effect) || reading.isClearNo($0, for: effect.id) }
            let quote = positive ?? negative ?? clauses.joined(separator: " / ")
            mentions.append(Mention(effectId: effect.id, presence: positive != nil ? .present : (negative != nil ? .absent : .unclear),
                                    locations: locations(in: quote), quote: quote))
        }
        if let key = request.slotKey, !mentions.contains(where: { $0.effectId == key }) {
            let presence: MentionPresence
            let compact = AnswerReading.normalized(text)
            let cannotRecall = compact.contains("기억") && ["안", "않", "못"].contains(where: compact.contains)
            if cannotRecall || reading.isUnknownAnswer(text) || reading.isVagueAnswer(text) {
                presence = .unclear
            } else if let effect = config.effect(key), reading.saysPresent(effect, text, answering: true) {
                presence = .present
            } else if reading.isShortYes(text) {
                presence = .present
            } else if reading.isClearNo(text, for: key) {
                presence = .absent
            } else {
                presence = .unclear
            }
            mentions.append(Mention(effectId: key, presence: presence, locations: locations(in: text), quote: text))
        } else if request.slotKey == nil, mentions.isEmpty, !reading.soundsFine(text), !reading.isClosing(text) {
            mentions.append(Mention(effectId: "other", otherName: "추가로 남긴 말",
                                    presence: reading.saysSymptom(text) ? .present : .unclear,
                                    locations: locations(in: text), quote: text))
        }
        return TurnResult(mentions: mentions)
    }

    private func locations(in text: String) -> [String] {
        // Keep the clause so left/right and the participant's wording survive conversion.
        AnswerReading.parts(text).filter { clause in bodyParts.parts.values.joined().contains(where: clause.contains) }
    }
}
