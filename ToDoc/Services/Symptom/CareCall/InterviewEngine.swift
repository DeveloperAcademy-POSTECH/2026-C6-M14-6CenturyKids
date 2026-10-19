//
//  InterviewEngine.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// 케어콜 대화 상태 머신. 화면·음성·AI 구현을 모르고 CareCallAI 프로토콜만 안다.
/// 환자 답 한 턴을 `handle(patientText:)`로 받아 기록하고, 다음에 할 말을 돌려준다. 다음 질문은 AI가 아니라 기록 상태로 정한다.
final class InterviewEngine {
    struct Output: Equatable, Sendable {
        var utterance: String
        var phase: InterviewPhase
        var isFinished: Bool { phase == .saved || phase == .emergencyEnded }
    }

    let config: CareCallConfig
    private let rules: EmergencyRules
    private let detector: KeywordMatcher
    private let symptomHints: KeywordMatcher
    private let openingConcerns: KeywordMatcher
    private let analyzer: any CareCallAI
    private let knownIds: Set<String>
    private let names: [String: String]
    private let keywords: [String: [String]]

    private(set) var phase: InterviewPhase = .opening
    private(set) var ledger = Ledger()
    /// 지금까지 쓴 맞장구 수 (문구를 차례로 돌린다)
    private var acknowledgementCount = 0
    private var otherAsked = false
    private var otherAttempts = 0
    /// '그 밖에'에서 말한 기타 증상: 한 번 더 물은 뒤 답을 그대로 기록할 항목
    private var otherDetailKey: String?
    /// 같은 질문을 다시 묻게 한 답 (불명확·분석 실패). 두 번 다시 물어도 분명하지 않아 항목을 닫으면 원문으로 남긴다. 키: "항목|단계"
    private var unsettledAnswers: [String: [String]] = [:]
    /// '그 밖에'에 "네"만 답해 무엇인지 이미 되물었음 (그 답에는 또 묻지 않는다)
    private var otherYesFollowedUp = false
    /// 첫 질문에 꼬리질문을 했으면 그 첫 답
    private var openingFirstAnswer: String?
    private var openingOtherName: String?
    /// 마지막으로 한 말 = 답을 기다리는 질문 (음성·문자를 바꿔도 이 질문부터 이어 간다)
    private(set) var lastQuestion: String
    /// 같은 날 다시 거는 통화면 오늘 기록에 아직 없는 항목(지난 통화가 끊겨 못 물음), 처음 통화면 nil.
    /// 다시 거는 통화는 "달라졌거나 새로 불편한 점"을 묻고, 그 답에서 나온 증상과 이 항목만 묻는다
    private let unasked: Set<String>?

    init(config: CareCallConfig, rules: EmergencyRules, analyzer: any CareCallAI, followUp unasked: Set<String>? = nil) {
        self.config = config
        self.rules = rules
        self.detector = KeywordMatcher(keywords: rules.keywords)
        self.symptomHints = KeywordMatcher(keywords: config.symptomHints, prefixNegation: true)
        self.openingConcerns = KeywordMatcher(keywords: config.openingConcerns, prefixNegation: true)
        self.analyzer = analyzer
        self.knownIds = Set(config.effects.map(\.id))
        self.names = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.name) })
        self.keywords = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.keywords) })
        self.unasked = unasked
        self.lastQuestion = unasked == nil ? config.openingQuestion : config.followUpCall.question
    }

    func start() -> Output {
        let question = unasked == nil ? config.openingQuestion : config.followUpCall.question
        return Output(utterance: say(question), phase: phase)
    }

    /// start() 뒤, 환자 답을 기다리는 동안 부른다 (첫 모델 턴 단축)
    func prewarm() async {
        await analyzer.prewarm(request(for: phase, patientText: ""))
    }

    /// 이 답을 handle하는 동안 모델을 부를 거면, 그동안 먼저 말할 맞장구 (음성 대화의 체감 대기 단축). 아니면 nil.
    /// 첫 질문 답은 넘어가는 말("알겠어요. 이제…")과 겹쳐서 쓰지 않는다. handle과 같은 판정을 쓰고 기록은 바꾸지 않는다.
    func acknowledgement(for patientText: String) -> String? {
        guard phase != .opening, phase != .saved, phase != .emergencyEnded, !config.acknowledgements.isEmpty,
              !isEmergencyText(patientText), quickResult(for: phase, patientText: patientText) == nil else { return nil }
        defer { acknowledgementCount += 1 }
        return config.acknowledgements[acknowledgementCount % config.acknowledgements.count]
    }

    func handle(patientText: String) async -> Output {
        guard phase != .saved, phase != .emergencyEnded else {
            return Output(utterance: "", phase: phase)
        }
        if isEmergencyText(patientText) {
            return endWithEmergency()
        }

        let current = phase
        var result: TurnResult?
        if let quick = quickResult(for: current, patientText: patientText) {
            result = quick
        } else {
            result = await analyze(current, patientText: patientText)
            // 처음·그 밖에에서 모델이 증상을 기록하지 않고 맞장구만 쓰거나("열이 조금 나신다고 하셨습니다."),
            // 증상 표현("머리가 좀 아파요")이나 목록 증상 낱말("설사", "올렸")이 있는데 아무것도 기록하지 않으면 한 번 더 분석한다
            // (2026-10-13 실기기 평가 102회: 목록 낱말로 다시 분석할 턴 4개 중 3개가 실제로 놓친 증상)
            if let r = result, Self.acknowledgedWithoutRecord(r, during: current)
                || Self.missedSymptomHint(r, during: current, patientText: patientText,
                                          hints: config.symptomHints + config.effects.flatMap(\.keywords)) {
                result = await analyze(current, patientText: patientText) ?? r
            }
        }
        if result?.emergencySignal == true {
            return endWithEmergency()
        }
        if let analyzed = result, let recheck = await recheckCorrection(analyzed, during: current, patientText: patientText) {
            result?.mentions += recheck
        }
        if let analyzed = result, let reason = reasonAnswer(analyzed, during: current, patientText: patientText) {
            result?.mentions.append(reason)
        }
        if let mentions = result?.mentions {
            result?.mentions = presentByPhrase(reassignedByKeywords(normalizedOthers(mentions, during: current, patientText: patientText),
                                                                    during: current, patientText: patientText), patientText: patientText)
        }
        if current == .opening, unasked != nil, let mentions = result?.mentions {
            result?.mentions = stoppedOverride(mentions, patientText: patientText)
        }
        // 지금 묻지 않은 항목의 '없음'은 환자가 그 항목 낱말을 말했을 때만 받는다. 모델이 상관없는 말("잠은 잘 자요",
        // "음 좀 어지러웠어요")을 근거로 식사를 '없음'으로 채워 식사 질문이 통째로 빠졌다 (2026-10-08 평가).
        // '있음'은 거르지 않는다: 낱말 목록이 초안이라 실제 증상을 놓칠 수 있고, '있음'은 횟수를 물으며 환자가 바로잡을 수 있다
        result?.mentions.removeAll { m in
            m.presence == .absent && m.effectId != current.slotKey
                && config.effects.first { $0.id == m.effectId }.map { !$0.keywords.contains(where: patientText.contains) } == true
        }
        // 한 답 안에서 같은 항목이 있음·없음으로 함께 나오면 있음만 받는다. 차례로 넣으면 번복으로 처리돼 마지막 '없음'이 남고
        // 그 증상을 다시 묻지 않는다 ("어제 좀 토했어요, 그거 말고는 괜찮아요" → 구토 있음+없음, 2026-10-13 실기기 평가).
        // '있음'은 횟수를 물으며 환자가 바로잡을 수 있다. 근거 없는 '있음'(Ledger가 버림)으로 '없음'을 지우지 않는다
        let presentKeys = Set((result?.mentions ?? []).filter { $0.presence == .present && Ledger.grounded($0.quote, in: patientText) }
            .map { Ledger.key(effectId: $0.effectId, otherName: $0.otherName) })
        result?.mentions.removeAll { $0.presence == .absent && presentKeys.contains(Ledger.key(effectId: $0.effectId, otherName: $0.otherName)) }
        let before = ledger
        var recordedPrefix: String? // '그 밖에' 기타 증상 기록 뒤 마무리 인사 앞에 붙이는 말
        for mention in result?.mentions ?? [] {
            ledger.apply(mention, patientText: patientText, knownEffectIds: knownIds,
                         mayChangeRecorded: mayChangeRecorded(mention, during: current, patientText: patientText))
        }
        prefillNumber(from: patientText, since: before, during: current)
        // 첫 질문 답은 그대로 남긴다 (꼬리질문의 답이면 첫 답과 이어서). 다시 거는 통화는 컨디션을 묻지 않는다
        if current == .opening, unasked == nil {
            ledger.setConditionText([openingFirstAnswer, patientText].compactMap { $0 }.joined(separator: " / "))
        }
        // 첫 질문: 증상 표현이나 컨디션이 나쁘다는 말이 있고 목록 증상은 기록되지 않았으면 한 번 되묻는다
        // ("피곤해요" → "어떤 점이 그러신지…". "보통이에요", "잠은 잘 자요"는 묻지 않음)
        if current == .opening, openingFirstAnswer == nil, result?.needsClarification != true,
           symptomHints.matches(patientText) != nil || openingConcerns.matches(patientText) != nil,
           !knownIds.contains(where: { ledger[$0]?.presence != before[$0]?.presence }) {
            openingFirstAnswer = patientText
            // 첫 답에서 생긴 기타 항목: 꼬리질문의 답에서 나온 이름 없는 기타는 여기에 붙인다 (같은 증상이 둘로 기록되지 않게)
            openingOtherName = ledger.order.first { $0.hasPrefix("other:") && before[$0] == nil }.flatMap { ledger[$0]?.otherName }
            return Output(utterance: say(config.openingFollowUp), phase: phase)
        }
        // 꼬리질문의 답이면 첫 답과 합쳐 본다 ('피곤해요 / 일을 많이 해서요')
        let answerText = current == .opening ? [openingFirstAnswer, patientText].compactMap { $0 }.joined(separator: " / ") : patientText
        recordVerbatimOtherIfMissed(result, during: current, patientText: patientText, text: answerText,
                                    unchanged: ledger.sameRecords(as: before))
        // 다시 거는 통화의 첫 답
        // - 말한 증상이 없는데 달라진 게 없다·없어졌다·모르겠다고 분명히 답하지도 않음("네"만, 분석 실패, 알아듣지 못한 답): 한 번 되묻는다
        // - "글쎄요"면 달라진 점을 '모름'으로 남긴다
        // - 분명히 달라진 게 없다면 '그 밖에'도 묻지 않는다 (첫 질문이 이미 물었다). 지난 통화에서 못 물은 항목이 있으면 묻고 '그 밖에'로 마무리
        if current == .opening, let unasked {
            // 증상이 없어졌다고만 말한 답("설사는 멈췄어요" → 이번 답으로 목록 증상 없음)은 알아들은 답이라 되묻지 않는다.
            // 연결어·숫자·나빠졌다는 말이 섞이면("멈췄는데 대신…") 놓친 증상이 있을 수 있어 되묻는다
            let mixed = ["근데", "그런데", "는데", "지만", "한데"].contains(where: Self.normalized(patientText).contains)
                || NumberParser.hasNumber(patientText) || openingConcerns.matches(patientText) != nil
            let toldAbsent = !mixed && ledger.order.contains { key in
                knownIds.contains(key) && ledger[key]?.presence == .absent && before[key]?.presence != .absent
            }
            let unclear = isUnclearChange(patientText), settled = unclear || isUnchanged(patientText)
            // 숫자가 섞여 모델이 봤는데 찾은 게 없는 "글쎄요 두 번?": 끝내지 않고 되묻되, 이 말은 '달라진 점' 모름 + 원문으로 남긴다
            if !unclear, !toldNewSymptom, ledger.sameRecords(as: before), openingConcerns.matches(patientText) == nil,
               (config.vagueAnswers + config.unknownAnswers).contains(where: { Self.normalized(patientText).contains(Self.normalized($0)) }) {
                recordUnclearChange(patientText)
            }
            if !toldNewSymptom, !settled, !toldAbsent, openingFirstAnswer == nil {
                openingFirstAnswer = patientText
                // 첫 답에서 생긴 기타 항목: 되물은 답에서 같은 증상을 또 기록하지 않게 (위의 되묻기와 같다).
                // 바로 위에서 남긴 '달라진 점' 모름은 증상이 아니라 제외한다 (되물은 답의 증상이 그 이름으로 붙지 않게)
                let unclearKey = Ledger.key(effectId: "other", otherName: config.followUpCall.unclearName)
                openingOtherName = ledger.order.first { $0.hasPrefix("other:") && $0 != unclearKey && before[$0] == nil }
                    .flatMap { ledger[$0]?.otherName }
                return Output(utterance: say(config.openingFollowUp), phase: phase)
            }
            if unclear { recordUnclearChange(patientText) }
            // '그 밖에'는 달라진 게 없다·모르겠다고 분명히 답했을 때만 생략한다 (없어졌다는 답 뒤에는 한 번 묻는다)
            if !toldNewSymptom { otherAsked = settled && unasked.isEmpty }
        }

        switch current {
        case .slot(let key, let step) where step != .detail
            && (isUnknownAnswer(patientText) || (step == .presence && isVagueAnswer(patientText))):
            ledger.markUnknown(key, step: step, quote: patientText) // '모름' + 원문
        case .other where otherDetailKey == nil && soundsUnsure(patientText) && ledger.sameRecords(as: before):
            // '그 밖에'에 "모르겠어요"·"그냥 그래요": 기타 '모름' + 원문으로 남기고 마무리 (증상 '있음'으로는 남기지 않는다)
            let name = config.otherUnclearName
            ledger.apply(Mention(effectId: "other", otherName: name, presence: .unclear, quote: patientText),
                         patientText: patientText, knownEffectIds: knownIds)
            ledger.markUnknown(Ledger.key(effectId: "other", otherName: name), step: .presence, quote: patientText)
            otherAsked = true
        case .slot(let key, .detail):
            // 이 답 전에 물은 꼬리질문 (꼬리질문 답은 모델 없이 처리해 그사이 기록이 바뀌지 않는다)
            if let detail = pendingDetail(for: key) {
                let answer = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                ledger.addDetail(answer, label: detail.label, for: key)
            }
        case .other:
            if let key = otherDetailKey {
                // 기타 증상 꼬리질문의 답 → 그대로 기록하고 마무리
                recordOtherDetail(patientText, for: key)
                otherAsked = true
                recordedPrefix = config.otherDetail.recorded
            } else if let key = ledger.order.last(where: { $0.hasPrefix("other:") && before[$0] == nil }) {
                // 새 기타 증상: 무엇인지 이미 되물은 답이면 바로 마무리, 아니면 한 번 더 묻는다
                if otherYesFollowedUp {
                    otherAsked = true
                    recordedPrefix = config.otherDetail.recorded
                } else {
                    otherDetailKey = key
                    return Output(utterance: say(config.otherDetail.question), phase: phase)
                }
            } else {
                // 분석이 실패하면 '그 밖에' 질문을 한 번 더 묻는다 (실패한 답의 증상을 버리지 않도록)
                otherAttempts += 1
                otherAsked = (result != nil && result?.needsClarification != true) || otherAttempts >= 2
                if result?.utterance == config.otherFollowUp { otherYesFollowedUp = true }
            }
        default:
            break
        }

        // 유무·부위 질문의 답이 분명하지 않으면(다시 묻게 됨) 답을 모아 둔다. 이 답으로 다른 증상이 기록됐으면 그 증상의 말이라 모으지 않는다
        if case .slot(let key, let step) = current, step != .detail,
           ledger.order.allSatisfy({ $0 == key || (ledger[$0]?.presence == before[$0]?.presence && ledger[$0]?.locations == before[$0]?.locations) }),
           let entry = ledger[key], !entry.unknownSteps.contains(step),
           step == .presence ? (entry.presence == nil || entry.presence == .unclear) : entry.locations.isEmpty {
            let said = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if !said.isEmpty { unsettledAnswers["\(key)|\(step)", default: []].append(said) }
        }
        let followUp = Self.validFollowUp(result?.utterance, patientText: patientText)
        let recordedThisTurn = !ledger.sameRecords(as: before) // advance()가 '물음' 표시를 남기기 전에 본다
        var utterance = await advance(from: current, followUp: followUp)
        if current == .opening, let unasked {
            // 다시 거는 통화: 말한 증상·못 물은 항목을 묻는다고 알리거나, 달라진 게 없으면 그대로 둔다고 말하고 마무리
            let f = config.followUpCall
            // 기타 증상만 말했으면 곧바로 '그 밖에'로 가므로 "말씀하신 증상에 대해 조금 더 여쭤볼게요"는 붙이지 않는다
            let toldListedSymptom = ledger.order.contains { knownIds.contains($0) && ledger[$0]?.presence == .present }
            let transition: String? = switch (toldListedSymptom, unasked.isEmpty) {
            case (true, true): f.noted
            case (true, false): f.notedAndResume
            case (false, false): f.resume
            case (false, true): isUnchanged(patientText) && !isUnclearChange(patientText) ? f.unchanged : nil
            }
            utterance = [transition, utterance].compactMap(\.self).joined(separator: " ")
        } else if current == .opening {
            // 증상 질문으로 넘어가며 한마디 ("좋아요. 이제 증상들에 대해서 물어볼게요.")
            let t = config.openingTransition
            let transition = openingFirstAnswer != nil ? t.afterFollowUp : recordedThisTurn ? t.noted : t.fine
            utterance = transition + " " + utterance
        }
        if let prefix = recordedPrefix {
            utterance = prefix + " " + utterance
        }
        return Output(utterance: utterance, phase: phase)
    }

    /// 모델이 고른 목록 증상의 낱말은 환자 말에 없고 다른 목록 증상 하나의 낱말만 있으면 그 증상으로 바꾼다
    /// ("요즘 입맛이 좀 없어요" → 모델은 구내염, 말한 낱말은 식사의 "입맛", 2026-10-17 실기기). 지금 묻는 항목의 답("네")은 그대로.
    /// 바꿀 증상을 고를 때는 한 글자 낱말("물", "먹", "토")을 쓰지 않는다 (다른 말 안에 흔히 들어 있다: "물을 마셔도", "토요일").
    /// 모델이 고른 증상을 지킬 때는 한 글자 낱말도 근거로 본다 ("물도 잘 안 넘어가고 입이 아파요"의 식사를 옮기지 않게)
    private func reassignedByKeywords(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        func said(_ id: String, minLength: Int) -> Bool {
            config.effects.first { $0.id == id }?.keywords.contains { $0.count >= minLength && patientText.contains($0) } == true
        }
        let saidIds = config.effects.map(\.id).filter { said($0, minLength: 2) }
        guard saidIds.count == 1, let target = saidIds.first, !mentions.contains(where: { $0.effectId == target }) else { return mentions }
        return mentions.map { mention in
            guard knownIds.contains(mention.effectId), mention.effectId != phase.slotKey, !said(mention.effectId, minLength: 1)
            else { return mention }
            var moved = mention
            moved.effectId = target
            return moved
        }
    }

    /// "입맛이 없어요"처럼 '없다'가 붙어도 증상이 있다는 말(presentPhrases)이면 그 증상을 '있음'으로 한다. 모델이 "없어요"만 보고
    /// 식사를 '없음'으로 기록해 식사 질문을 건너뛰었다 (2026-10-19 실기기). "입맛 없는 건 아니에요"처럼 부정하면 그대로 둔다
    private func presentByPhrase(_ mentions: [Mention], patientText: String) -> [Mention] {
        var result = mentions
        for effect in config.effects where saysPresent(effect, patientText) {
            result.removeAll { $0.effectId == effect.id && $0.presence != .present }
            if !result.contains(where: { $0.effectId == effect.id }) {
                result.append(Mention(effectId: effect.id, presence: .present, quote: patientText))
            }
        }
        return result
    }

    private func saysPresent(_ effect: CareCallConfig.Effect, _ patientText: String) -> Bool {
        (effect.presentPhrases ?? []).contains { phrase in
            let words = phrase.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard let regex = try? Regex(words.joined(separator: ".{0,8}?")) else { return false }
            // 한 절 안에서 차례로 나오고, 바로 뒤가 부정("입맛 없는 건 아니에요")이 아닐 때.
            // 약을 먹는 이야기("약을 잘 못 먹어요", "식사 후에 약을 못 먹었어요")는 아니다: 맞은 말 안이나 바로 앞에 약이 있을 때.
            // "약을 먹고 나서 입맛이 없어요"는 식사 증상이다. "약간"은 약이 아니다
            return KeywordMatcher.clauses(patientText).contains { clause in
                guard let match = clause.firstMatch(of: regex),
                      clause[match.range].firstMatch(of: /약(?:을|은|이|도|만|\s)/) == nil,
                      clause[..<match.range.lowerBound].firstMatch(of: /약(?:을|은|이|도|만)?\s*$/) == nil else { return false }
                return !KeywordMatcher.negated(String(clause[match.range.upperBound...]).replacingOccurrences(of: " ", with: ""))
            }
        }
    }

    /// 다시 거는 통화의 첫 답이 "구토는 멈췄어요"처럼 답 전체가 "증상 낱말 + (조사) + 그쳤다는 말 + 끝맺음"이면
    /// 그 증상을 '없음'으로 한다. 모델이 못 잡거나(되물은 뒤 "없어요"로 그쳤다는 말이 사라짐, 2026-10-17) '있음'으로 잡아도
    /// ("구토가 나아졌어요" → 횟수만 묻고 말이 사라짐, 2026-10-19 실기기) 같다.
    /// 그 밖의 말("안", "아직", "좀", "같아요", 다른 증상)이 있으면 모델 판단 그대로 둔다
    private func stoppedOverride(_ mentions: [Mention], patientText: String) -> [Mention] {
        let text = Self.normalized(patientText)
        let stems = config.followUpCall.stoppedAnswers.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = "^(?:이제|지금은)?([가-힣]{2,6}?)(?:은|는|이|가|도)?(?:이제|다)?(?:\(stems))(?:어요|어|요|습니다|네요)?$"
        guard let regex = try? Regex(pattern), let match = text.firstMatch(of: regex), let range = match.output[1].range else { return mentions }
        // 증상 낱말이 두 글자 이상 키워드 그대로이거나 키워드 + 이름 끝말이면 그 증상 ("메스꺼움" = "메스" + "꺼움", "가려움" = "가려" + "움").
        // 다른 말이 붙으면("구토는좀") 아니다
        let symptom = String(text[range])
        let said = config.effects.filter { effect in
            effect.keywords.contains { $0.count >= 2 && symptom.hasPrefix($0) && ["", "꺼움", "거림", "움"].contains(String(symptom.dropFirst($0.count))) }
        }
        guard said.count == 1, let effect = said.first else { return mentions }
        return mentions.filter { $0.effectId != effect.id } + [Mention(effectId: effect.id, presence: .absent, quote: patientText)]
    }

    /// 증상 유무 질문에 횟수·지속 시간까지 답하면 그 꼬리질문의 답으로 채워 다시 묻지 않는다
    /// ("구토를 하셨나요?" → "네 한 번 토했어요" → 구토 횟수 1. 2026-10-17 실기기에서 횟수를 또 물음).
    /// 숫자가 다른 일(약·식사)이나 시작 시점일 수 있어 좁게 본다 (아니면 지금처럼 묻는다):
    /// - 그 증상의 유무 질문에 대한 답이고, 이번 답으로 '있음'이 된 목록 증상이 그것 하나
    /// - 숫자가 그 꼬리질문 낱말(없으면 증상 낱말)과 같은 절에 있고, 답의 다른 곳에는 숫자가 없을 때
    /// - 숫자가 분명할 때만 ("두세 번", "열 번 넘게"는 묻는다)
    /// - 지속 시간은 "씩·동안·정도·가요"처럼 지속을 뜻하는 말이 있고 "전·부터·됐·째" 같은 시작 시점 말이 없을 때만
    private func prefillNumber(from patientText: String, since before: Ledger, during current: InterviewPhase) {
        guard case .slot(let key, .presence) = current, let entry = ledger[key], entry.presence == .present,
              before[key]?.presence != .present, let effect = config.effects.first(where: { $0.id == key }),
              ledger.order.filter({ knownIds.contains($0) && ledger[$0]?.presence == .present && before[$0]?.presence != .present }) == [key]
        else { return }
        for detail in effect.details where !entry.details.contains(where: { $0.label == detail.label }) {
            let gate = KeywordMatcher(keywords: detail.keywords ?? effect.keywords, prefixNegation: true)
            let clauses = KeywordMatcher.clauses(patientText)
            guard let clause = clauses.first(where: { gate.matches($0) != nil }),
                  clauses.filter({ $0 != clause }).allSatisfy({ NumberParser.count(in: $0) == nil && NumberParser.minutes(in: $0) == nil })
            else { continue }
            // 저장할 때는 문장 전체에서 다시 읽는다. 그 절과 같은 값이 읽힐 때만 채운다
            // ("한 번 토했어요, 그 전날은 두세 번"은 전체가 어림수라 횟수가 비어 저장되므로 묻는다)
            let found = switch detail.number {
            case .count?: NumberParser.count(in: clause).map { $0 == NumberParser.count(in: patientText) } ?? false
            case .minutes?: NumberParser.minutes(in: clause).map { $0 == NumberParser.minutes(in: patientText) } ?? false
                && Self.durationMarkers.contains(where: clause.contains) && !Self.onsetMarkers.contains(where: patientText.contains)
            case nil: false
            }
            if found { ledger.addDetail(patientText.trimmingCharacters(in: .whitespacesAndNewlines), label: detail.label, for: key) }
        }
    }

    private static let durationMarkers = ["씩", "동안", "정도", "가요", "계속", "지속"]
    private static let onsetMarkers = ["전", "부터", "됐", "지났", "째", "시작"]

    /// 다시 거는 통화에서 새로 '있음'으로 말한 증상이 있음 (기타 포함)
    private var toldNewSymptom: Bool {
        ledger.order.contains { ledger[$0]?.presence == .present }
    }

    /// 다시 거는 통화의 첫 질문에 "글쎄요"·"잘 모르겠어요": 달라진 점을 '모름'으로 남긴다 (의료진이 원문을 본다)
    private func recordUnclearChange(_ patientText: String) {
        let name = config.followUpCall.unclearName
        ledger.apply(Mention(effectId: "other", otherName: name, presence: .unclear, quote: patientText),
                     patientText: patientText, knownEffectIds: knownIds)
        ledger.markUnknown(Ledger.key(effectId: "other", otherName: name), step: .presence, quote: patientText)
    }

    private func recordOtherDetail(_ patientText: String, for key: String) {
        let answer = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        ledger.addDetail(answer, label: config.otherDetail.label, for: key)
        otherDetailKey = nil
    }

    func ledgerSummary() -> String {
        ledger.summaryText(names: names)
    }

    // MARK: - 진행

    private func advance(from current: InterviewPhase, followUp: String?) async -> String {
        while true {
            // 다시 거는 통화는 이번에 말한 항목과 지난 통화에서 못 물은 항목만 묻는다
            switch SlotPlanner.next(ledger: ledger, config: config, otherAsked: otherAsked, only: unasked.map { $0.union(ledger.order) }) {
            case .slot(let key, let step):
                guard ledger.markAsked(key, step: step) else {
                    // 두 번 다시 물어도 분명하지 않아 닫음 → 그동안 받은 답을 원문으로 남기고 다음 항목
                    ledger.addUnsure(unsettledAnswers.removeValue(forKey: "\(key)|\(step)") ?? [], step: step, for: key)
                    continue
                }
                let isRepeat = current == .slot(key: key, step: step)
                phase = .slot(key: key, step: step)
                let q = question(key: key, step: step, followUp: isRepeat ? followUp : nil)
                // 오류·불분명으로 같은 질문을 다시 하면 다시 묻는다고 말한다 (모델이 다른 말로 되묻는 경우는 제외)
                if isRepeat && q == lastQuestion { return say(config.repeatPrefix + " " + q) }
                // 다른 항목·'그 밖에'를 묻다가 이 항목의 횟수·부위로 돌아가면 무엇을 묻는지 이름을 먼저 말한다
                // (첫 질문 답에서 바로 이어 물을 때는 환자가 방금 말한 증상이라 붙이지 않는다)
                // (2026-10-08 기기: 식사 질문 뒤 구내염을 이름 없이 다시 물어 환자가 식사에 대한 답을 함)
                // 질문에 이미 증상 이름이 있으면("설사는 하루에 몇 번…") 붙이지 않는다
                if step != .presence, current != .opening, current.slotKey != key, let effect = config.effects.first(where: { $0.id == key }),
                   !([effect.spokenName] + effect.keywords.filter { $0.count >= 2 }).contains(where: q.contains) {
                    return say(config.returnPrefix(for: effect) + " " + q)
                }
                return say(q)
            case .other:
                phase = .other
                guard current == .other else { return say(config.otherQuestion) }
                return say(followUp ?? config.repeatPrefix + " " + config.otherQuestion)
            case .done:
                // 정리 문장(요약 확인)은 읽지 않고 바로 마무리 인사 (요약 기능은 계약 변경안 5번에 따라 없음)
                phase = .saved
                return say(rules.closingMessage)
            }
        }
    }

    /// 이미 기록된 값을 바꿔도 되는지. 지금 묻는 항목이거나 환자가 그 증상을 직접 말한 경우만 .
    /// 다른 항목을 묻는 중 "없어요", "네, 맞아요" 같은 짧은 답을 모델이 엉뚱한 항목에 붙여 기록을 뒤집는 것을 막는다.
    private func mayChangeRecorded(_ mention: Mention, during phase: InterviewPhase, patientText: String) -> Bool {
        switch phase {
        case .slot(let key, _) where key == mention.effectId: return true
        default:
            let words = mention.effectId == "other" ? [mention.otherName ?? ""].filter { !$0.isEmpty } : keywords[mention.effectId] ?? []
            return words.contains { patientText.contains($0) }
        }
    }

    /// 기타(목록 밖) 증상 정리. 모델은 기타 증상의 이름을 비우고 근거를 낱말로 쪼개거나("열", "조금"), 예시의 이름을 베끼기도 한다("네" → "피로").
    /// - 모델이 준 이름은 환자 말에 있고 숫자가 없을 때만 쓴다
    /// - 이름 없는 기타(기타 항목을 다시 묻는 중이면 이름이 있어도): 그 항목, 처음·그 밖에면 이번 발화 전체를 이름으로 하나만 (있음일 때만)
    /// - 그 밖의 단계(목록 항목 질문)의 이름 없는 기타는 버린다
    private func normalizedOthers(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        var kept: [Mention] = []
        var unnamed: [Mention] = []
        for var m in mentions {
            guard m.effectId == "other" || !knownIds.contains(m.effectId) else { kept.append(m); continue }
            if knownIds.contains(where: { m.effectId.hasPrefix($0) }) { kept.append(m); continue } // Ledger가 버린다
            m.effectId = "other"
            let currentOther: Bool = if case .slot(let key, _) = phase { key.hasPrefix("other:") } else { false }
            if !currentOther, let name = m.otherName?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
               patientText.contains(name), NumberParser.numbers(in: name).isEmpty { // "3번이요" 같은 숫자 답은 이름이 아니다
                kept.append(m)
            } else {
                m.otherName = nil
                unnamed.append(m)
            }
        }
        guard let first = unnamed.first else { return kept }
        var merged = first
        merged.quote = patientText
        switch phase {
        case .slot(let key, _) where key.hasPrefix("other:"):
            merged.otherName = ledger[key]?.otherName
        case .opening, .other:
            guard unnamed.contains(where: { $0.presence == .present }) else { return kept }
            merged.presence = .present
            merged.otherName = (phase == .opening ? openingOtherName : nil)
                ?? patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        default:
            return kept
        }
        return merged.otherName == nil ? kept : kept + [merged]
    }

    /// 형식 출력이 잘리면(구조화 출력 실패, 2026-10-08 재평가 90회 중 7회) 같은 답을 한 번 더 분석한다.
    /// 같은 모델 객체의 다음 호출은 출력이 달라져 대개 성공하고, 되묻기(질문을 다시 듣고 답하기)보다 짧다
    private func analyze(_ phase: InterviewPhase, patientText: String) async -> TurnResult? {
        for _ in 0..<2 {
            do {
                return try await analyzer.analyze(request(for: phase, patientText: patientText))
            } catch {
                if error is CancellationError || Task.isCancelled { return nil }
            }
        }
        return nil
    }

    static func acknowledgedWithoutRecord(_ result: TurnResult, during phase: InterviewPhase) -> Bool {
        switch phase {
        case .opening, .other: break
        default: return false
        }
        let u = result.utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.mentions.isEmpty && !result.needsClarification && !u.isEmpty && !u.contains("?")
    }

    /// 처음·그 밖에에서 이번 답으로 기록이 하나도 바뀌지 않았는데(모델이 비웠거나, 엉뚱한 항목에 붙여 막혔거나)
    /// 증상 표현이 부정 없이 있으면, 환자 말 그대로 기타 증상으로 기록하고 검토 필요로 둔다. 이름을 짓지 않는다 (의료진이 원문을 본다)
    private func recordVerbatimOtherIfMissed(_ result: TurnResult?, during phase: InterviewPhase, patientText: String, text: String,
                                             unchanged: Bool) {
        switch phase {
        case .opening, .other: break
        default: return
        }
        // 첫 답·'그 밖에'에서 이미 기타 항목이 생겼으면 꼬리질문 답으로 또 만들지 않는다
        if phase == .opening, openingOtherName != nil { return }
        if otherDetailKey != nil { return }
        // 분석 실패(nil)도 포함: 실패한 답의 증상을 버리지 않는다
        // '그 밖에'는 부정이 아닌 답이면 증상 낱말이 없어도 기록한다: 음성 인식이 뭉갠 답("잠을 잠 못 잡니다")은
        // 낱말 목록에 안 걸려 맞장구만 하고 버려졌다 (2026-10-08 기기). 원문 그대로 두고 검토 필요로 표시한다
        // 다시 거는 통화의 첫 답에서 나빠졌다는 말("좀 안 좋아졌어요")은 컨디션으로 저장하지 않으니 기타로 남긴다
        // '그 밖에'에서 증상 표현이 있으면 모델이 되물어도 먼저 남긴다: 되물은 답이 "없어요"면 증상이 사라졌다
        // ("잘 모르겠는데 머리가 아파요", 2026-10-19 실기기). 남기면 "어떤 점이 그러신지"를 물어 내용을 받는다
        let keepAnyway = phase == .other && symptomHints.matches(text) != nil
        guard unchanged, result?.needsClarification != true || keepAnyway,
              symptomHints.matches(text) != nil
                || (phase == .other && !soundsNegative(text) && !soundsUnsure(text))
                || (phase == .opening && unasked != nil && openingConcerns.matches(text) != nil) else { return }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        ledger.apply(Mention(effectId: "other", otherName: name, presence: .present, quote: patientText),
                     patientText: patientText, knownEffectIds: knownIds)
        ledger.markNeedsReview(Ledger.key(effectId: "other", otherName: name))
    }

    /// "잘 모르겠어요", "기억이 안 나요" 같은 답. 숫자·없음 표현·연결어·증상 낱말이 함께 있으면 아니다
    /// ("모르겠는데 3번쯤", "잘 모르겠지만 좀 메스꺼웠어요"는 모델이 본다)
    private func isUnknownAnswer(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        guard config.unknownAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(text), !soundsNegative(text) else { return false }
        if ["는데", "지만", "근데", "그런데"].contains(where: text.contains) { return false }
        return !config.effects.flatMap(\.keywords).contains(where: text.contains) && symptomHints.matches(text) == nil
    }

    /// 유무 질문에 있다고도 없다고도 하지 않은 답 ("그냥 좀 그래요", "글쎄요"). 있다·없다는 말, 숫자, 연결어, 증상 낱말·표현이
    /// 함께 있으면 아니다 ("그냥 그래요, 없어요", "좀 그래요, 속이 메스꺼워요"는 지금처럼 판단한다)
    private func isVagueAnswer(_ text: String) -> Bool {
        let t = Self.withoutFillers(text, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard config.vagueAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(t), !soundsNegative(t),
              !["있", "했"].contains(where: compact.contains),
              !config.shortAnswers.yes.contains(where: { compact.hasPrefix(Self.normalized($0)) }) else { return false }
        if ["는데", "지만", "근데", "그런데"].contains(where: t.contains) { return false }
        return !config.effects.flatMap(\.keywords).contains(where: t.contains) && symptomHints.matches(t) == nil
    }

    /// 모르겠다·애매하다는 말만 있는 답 (숫자는 섞여도 된다). '그 밖에'에서 이런 답을 증상 '있음'으로 남기지 않고 '모름' + 원문으로 남길 때 쓴다.
    /// 증상 낱말·표현이나 없다는 말이 있으면 아니다 ("모르겠는데 머리가 아파요"는 증상으로, "모르겠어요 없는 것 같아요"는 없음으로)
    private func soundsUnsure(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        guard (config.unknownAnswers + config.vagueAnswers).contains(where: { compact.contains(Self.normalized($0)) }),
              !soundsNegative(text), symptomHints.matches(text) == nil else { return false }
        return !config.effects.flatMap(\.keywords).contains(where: text.contains)
    }

    /// 없다는 뜻이 담긴 답 ("없어요", "딱히 없는 것 같아요", "괜찮아요", "아니요 그냥 그래요")
    /// "읎"은 사투리 "읎어요·읎심더"
    private func soundsNegative(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        return ["없", "읎", "괜찮", "아니", "아뇨"].contains(where: compact.contains)
            || config.noSuffixes.contains(where: { compact.hasSuffix(Self.normalized($0)) })
    }

    static func missedSymptomHint(_ result: TurnResult, during phase: InterviewPhase, patientText: String, hints: [String]) -> Bool {
        switch phase {
        case .opening, .other: break
        default: return false
        }
        // ponytail: 낱말 목록 휴리스틱. "안 아파요"처럼 부정이어도 다시 분석할 뿐(기록은 모델이 정함), 비용은 모델 호출 1회
        return result.mentions.isEmpty && !result.needsClarification && hints.contains { patientText.contains($0) }
    }

    /// 번복 확인: 다른 항목을 묻는 중 환자가 이미 기록된 증상을 다시 말했는데("아, 어제 토했어요") 모델이 그 증상을 뽑지 않았으면,
    /// 그 항목을 묻는 질문으로 모델을 한 번 더 부른다. 추출은 모델이, 다시 부를지는 엔진이 정한다.
    /// 아직 기록 없는 증상은 나중에 차례대로 물으므로 다시 부르지 않는다. 항목 질문 단계에서만.
    private func recheckCorrection(_ result: TurnResult, during phase: InterviewPhase, patientText: String) async -> [Mention]? {
        // 기타 질문은 첫 호출이 이미 모든 항목을 보고, "아니요, 설사는 4점" 같은 답을 '없음'으로 다시 읽을 위험이 있어 하지 않는다
        guard case .slot(let currentKey, _) = phase else { return nil }
        let mentioned = Set(result.mentions.map(\.effectId))
        guard let effect = config.effects.first(where: { e in
            e.id != currentKey && !mentioned.contains(e.id) && ledger[e.id]?.presence != nil
                && e.keywords.contains { patientText.contains($0) }
        }) else { return nil }
        var request = AnalysisRequest(patientText: patientText, question: effect.ask, ledgerSummary: ledgerSummary())
        request.slotKey = effect.id
        request.step = .presence
        request.slotName = effect.name
        guard let recheck = try? await analyzer.analyze(request) else { return nil }
        return recheck.mentions.filter { $0.effectId == effect.id }
    }

    /// 짧고 분명한 답은 모델 없이 처리한다 (속도·재현성). 해당하지 않으면 nil → 모델 호출
    /// - 유무 단계: "네"는 있음, "아니요·없어요·괜찮아요"는 없음
    /// - 처음·그 밖에 질문의 "없어요" → 기록할 것 없음
    private func quickResult(for phase: InterviewPhase, patientText fullText: String) -> TurnResult? {
        // 앞에 붙는 "어", "응 어" 같은 말을 낱말 단위로 떼고 판정한다 ("응 어 있어" → "있어")
        let patientText = Self.withoutFillers(fullText, fillers: config.shortAnswers.fillers)
        let text = Self.normalized(patientText)
        let yes = isShortYes(patientText), no = config.shortAnswers.no.contains(text)
        switch phase {
        case .other where otherDetailKey != nil:
            // 기타 증상 꼬리질문의 답: 모델 없이 그대로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .slot(let key, .presence) where yes || no || isClearNo(patientText, for: key):
            let entry = ledger[key]
            let mention = Mention(effectId: entry?.effectId ?? key, otherName: entry?.otherName,
                                  presence: yes && !no ? .present : .absent, quote: fullText)
            return TurnResult(mentions: [mention], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .other where yes: // "네"만: 무엇이 불편한지 되묻는다 (모델이 "네"를 증상으로 기록하지 않도록)
            return TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: true,
                              emergencySignal: false, utterance: config.otherFollowUp)
        case .slot(_, .presence) where isUnknownAnswer(patientText) || isVagueAnswer(patientText),
             .slot(_, .location) where isUnknownAnswer(patientText),
             .other where isUnknownAnswer(patientText) || isVagueAnswer(patientText):
            // "모르겠어요"·"그냥 그래요": 모델 없이 '모름' + 원문으로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .slot(_, .detail): // 횟수·시작 시점·지속 시간·섭취량: 모델 없이 환자 말 그대로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        // 달라진 게 없다는 답은 짧을 때만 모델 없이 처리한다 ("똑같아요", "없어요"). 긴 답은 증상이 섞였을 수 있어 모델이 먼저 본다
        // ("요즘 입맛이 좀 없어요"). 모델이 찾은 게 없고 달라진 게 없다는 말이면 그때 마친다 (handle)
        case .opening where unasked != nil && (yes || (isUnchanged(patientText) && text.count <= 8) || isUnclearChange(patientText)):
            // 다시 거는 통화: 달라진 게 없음·모르겠음 → 기록할 증상 없음 ("글쎄요"는 아래에서 '모름'으로 남긴다), "네"만 → 아래에서 되묻는다
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .opening where no || isOpeningFine(patientText), .other where no:
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        default:
            return nil
        }
    }

    /// 유무 질문에 분명한 '없음' ("아니요 변 잘 봤어요", "설사는 안 했어요"): 없음 표현으로 시작하거나 끝나고,
    /// 지금 항목 밖의 증상 낱말·증상 표현·숫자·연결어("근데", "는데", "지만")가 없을 때만. 하나라도 있으면 모델이 판단
    private func isClearNo(_ patientText: String, for key: String) -> Bool {
        guard !key.hasPrefix("other:") else { return false }
        // "입맛이 없어요"는 '없어요'로 끝나도 식사 증상이 있다는 말이다
        if let effect = config.effects.first(where: { $0.id == key }), saysPresent(effect, patientText) { return false }
        let t = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let compact = Self.normalized(t)
        // 없음 표현으로 시작만 하면 뒷말이 번복일 수 있어("아니요 설사 맞아요 설사 했어요") 없음 표현 하나뿐일 때만 인정
        guard config.noPrefixes.contains(where: { compact == Self.normalized($0) })
                || config.noSuffixes.contains(where: { compact.hasSuffix(Self.normalized($0)) }) else { return false }
        if ["근데", "그런데", "는데", "지만", "그리고", "대신"].contains(where: { t.contains($0) }) { return false }
        if NumberParser.hasNumber(t) { return false }
        let otherKeywords = config.effects.filter { $0.id != key }.flatMap(\.keywords)
        if otherKeywords.contains(where: { t.contains($0) }) { return false }
        return symptomHints.matches(t) == nil
    }

    /// 유무 질문에 이유만 답하면 있음 ("식사를 적게 드시나요?" → "입이 아파서요" = 입이 아파서 많이 못 먹었다).
    /// 모델은 이유 쪽 증상(구내염)만 기록하고 지금 항목을 비워 같은 질문을 되풀이하기 쉬워 엔진이 채운다.
    /// 모델이 지금 항목을 근거와 함께 기록했거나(없음 포함) 없음 표현으로 시작하면 손대지 않는다
    private func reasonAnswer(_ result: TurnResult, during phase: InterviewPhase, patientText: String) -> Mention? {
        guard case .slot(let key, .presence) = phase, !key.hasPrefix("other:"),
              !result.mentions.contains(where: { $0.effectId == key && Ledger.grounded($0.quote, in: patientText) })
        else { return nil }
        let compact = Self.normalized(Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers))
        guard config.reasonSuffixes.contains(where: { compact.hasSuffix(Self.normalized($0)) }),
              !["에서", "에서요"].contains(where: compact.hasSuffix), // "집에서요"는 이유가 아니다
              !config.noPrefixes.contains(where: { compact.hasPrefix(Self.normalized($0)) }) else { return nil }
        return Mention(effectId: key, presence: .present, quote: patientText)
    }

    /// 다시 거는 통화의 첫 질문에 "글쎄요"·"잘 모르겠어요" (증상 낱말·숫자·연결어가 있으면 모델이 본다)
    private func isUnclearChange(_ patientText: String) -> Bool {
        // 나빠졌다는 말이 섞이면 모델이 본다 ("글쎄요, 좀 안 좋아진 것 같기도 하고요")
        guard openingConcerns.matches(patientText) == nil else { return false }
        if isUnknownAnswer(patientText) { return true }
        let compact = Self.normalized(patientText)
        // 숫자가 섞이면 모델이 본다 ("글쎄요 두 번?"). 모델이 찾은 게 없으면 원문은 handle에서 남긴다
        guard config.vagueAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(patientText),
              !["는데", "지만", "근데", "그런데"].contains(where: patientText.contains) else { return false }
        return !config.effects.flatMap(\.keywords).contains(where: patientText.contains) && symptomHints.matches(patientText) == nil
    }

    /// 다시 거는 통화의 첫 질문에 달라진 게 없다는 답 ("똑같아요", "그대로예요", "없어요", "괜찮아요").
    /// 연결어·숫자·증상 낱말·증상 표현이 있으면 아니다 ("똑같은데 어제 설사를 했어요"는 모델이 본다)
    private func isUnchanged(_ patientText: String) -> Bool {
        let t = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard soundsNegative(t) || config.followUpCall.unchangedAnswers.contains(where: { compact.contains(Self.normalized($0)) })
        else { return false }
        if ["근데", "그런데", "는데", "지만", "한데"].contains(where: { compact.contains($0) }) { return false }
        // "똑같지 않아요", "그대로가 아니에요": 달라졌다는 뜻이라 모델이 본다 (띄어쓰기 없이 비교)
        if ["지않", "진않", "가아니", "이아니", "게아니"].contains(where: { compact.contains($0) }) { return false }
        if NumberParser.hasNumber(t) { return false }
        if config.effects.flatMap(\.keywords).contains(where: { t.contains($0) }) { return false }
        return symptomHints.matches(t) == nil && openingConcerns.matches(t) == nil
    }

    /// 첫 질문의 답이 '좋아요·보통이에요' 류이고 증상 표현·나쁘다는 말·연결어("좋긴 한데 피곤해요")가 없으면 true (모델 생략)
    private func isOpeningFine(_ patientText: String) -> Bool {
        let t = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard config.openingFine.contains(where: { compact.contains(Self.normalized($0)) }) else { return false }
        if ["근데", "그런데", "는데", "지만", "한데", "긴 한데"].contains(where: { t.contains($0) }) { return false }
        // 증상 낱말이 있으면 모델이 본다 ("어제 좀 토했어요, 그거 말고는 괜찮아요")
        if config.effects.flatMap(\.keywords).contains(where: { t.contains($0) }) { return false }
        return symptomHints.matches(t) == nil && openingConcerns.matches(t) == nil
    }

    /// 앞쪽의 군말 낱말을 뗀다. 띄어쓰기로 나뉜 낱말 전체가 목록과 같을 때만 떼고, 남는 낱말이 없으면 원문 그대로
    /// ("음 아프지 않아" → "아프지 않아", "아프지 않아" → 그대로, "응" → 그대로)
    static func withoutFillers(_ text: String, fillers: [String]) -> String {
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let bare = { (w: String) in w.trimmingCharacters(in: .punctuationCharacters) }
        while words.count > 1, let first = words.first, fillers.contains(bare(first)) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private func isShortYes(_ patientText: String) -> Bool {
        config.shortAnswers.yes.contains(Self.normalized(patientText))
    }

    /// 꼬리질문은 짧게 다시 묻는 말이다 (설정 질문은 길어야 30자 안팎)
    static let maxFollowUpLength = 45

    static func normalized(_ s: String) -> String { String(s.filter { !$0.isWhitespace && !$0.isPunctuation }) }

    /// 모델 꼬리질문은 물음표로 끝나는 짧은 한 문장이고 환자 말을 되풀이하지 않을 때만 쓴다. 아니면 설정 문구로 다시 묻는다
    /// (2026-10-09 평가: "…있으신가요? (예: 어느 부분, 얼마나 심한지 등 …)"처럼 괄호·여러 문장이 그대로 읽힘)
    static func validFollowUp(_ utterance: String?, patientText: String) -> String? {
        guard let text = utterance?.trimmingCharacters(in: .whitespacesAndNewlines), text.hasSuffix("?"),
              text.count <= maxFollowUpLength, text.filter({ ".?!".contains($0) }).count == 1,
              !text.contains(where: { "()[]:".contains($0) }) else { return nil }
        let u = normalized(text), p = normalized(patientText)
        guard !u.isEmpty, !p.isEmpty else { return u.isEmpty ? nil : text }
        return u.contains(p) || p.contains(u) ? nil : text
    }

    /// 새 항목은 설정 파일 문구, 같은 항목 재질문은 모델 꼬리질문
    private func question(key: String, step: CareCallStep, followUp: String?) -> String {
        let model = followUp?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step {
        case .presence:
            if let model, !model.isEmpty { return model }
            return config.effects.first { $0.id == key }?.ask ?? config.otherQuestion
        case .detail:
            return pendingDetail(for: key)?.question ?? config.otherQuestion
        case .location:
            if let model, !model.isEmpty { return model }
            return config.locationPrompt
        }
    }

    /// 지금 묻는 세부 질문이 받는 숫자 (횟수·지속 시간). 문자 대화에서 입력 칸을 고른다. 글자로 받으면 nil
    var expectedNumber: CareCallConfig.Effect.Detail.Number? {
        guard case .slot(let key, .detail) = phase else { return nil }
        return pendingDetail(for: key)?.number
    }

    private func pendingDetail(for key: String) -> CareCallConfig.Effect.Detail? {
        guard let entry = ledger[key], let effect = config.effects.first(where: { $0.id == key }) else { return nil }
        return SlotPlanner.pendingDetail(entry, effect: effect)
    }

    private func request(for phase: InterviewPhase, patientText: String) -> AnalysisRequest {
        var request = AnalysisRequest(patientText: patientText, question: lastQuestion, ledgerSummary: ledgerSummary())
        if case .slot(let key, let step) = phase {
            request.slotKey = key
            request.step = step
            request.slotName = names[key] ?? ledger[key]?.otherName ?? key
        }
        return request
    }

    /// 응급 키워드 또는 기준 이상 체온 (모델 판단과 별개로 엔진이 정한다)
    private func isEmergencyText(_ text: String) -> Bool {
        detector.matches(text) != nil || rules.mentionsFever(text)
    }

    private func endWithEmergency() -> Output {
        phase = .emergencyEnded
        say(rules.message)
        return Output(utterance: rules.message, phase: phase)
    }

    /// 할 말을 마지막 질문으로 기억한다 (다음 분석 요청의 질문, 같은 질문 반복 판단에 쓴다)
    @discardableResult
    private func say(_ text: String) -> String {
        lastQuestion = text
        return text
    }
}
