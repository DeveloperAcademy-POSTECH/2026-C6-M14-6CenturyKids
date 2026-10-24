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
    private let crisisDetector: KeywordMatcher
    private let symptomHints: KeywordMatcher
    private let openingConcerns: KeywordMatcher
    private let analyzer: any CareCallAI
    /// 환자 답의 말 판단 (없다는 말, 애매한 답, 되묻는 말 등). 엔진 상태를 쓰지 않는다
    private let reading: AnswerReading
    private let knownIds: Set<String>
    private let names: [String: String]
    private let keywords: [String: [String]]

    private(set) var phase: InterviewPhase = .opening
    private(set) var ledger = Ledger()
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
    /// 모델만 응급이라고 본 답 뒤에 확인 질문을 했으면, '아니요'일 때 이어 갈 말과 단계
    private var pendingEmergencyCheck: (output: Output, phase: InterviewPhase)?
    /// 이번 답에서 근거 없이 고른 목록 증상을 기타로 돌렸음 (새 기타 항목을 검토 필요로 둔다)
    private var convertedToOther = false
    /// 같은 날 다시 거는 통화면 오늘 기록에 아직 없는 항목(지난 통화가 끊겨 못 물음), 처음 통화면 nil.
    /// 다시 거는 통화는 "달라졌거나 새로 불편한 점"을 묻고, 그 답에서 나온 증상과 이 항목만 묻는다
    private let unasked: Set<String>?
    /// 부위 낱말 (body_parts.json). 절 판단으로 '있음'이 된 답에서 그 절의 부위를 찾을 때만 쓴다
    private let locationWords: [String]

    init(config: CareCallConfig, rules: EmergencyRules, analyzer: any CareCallAI, followUp unasked: Set<String>? = nil,
         locationWords: [String] = []) {
        self.config = config
        self.rules = rules
        self.detector = KeywordMatcher(keywords: rules.keywords, maxGapWords: 2)
        self.crisisDetector = KeywordMatcher(keywords: rules.crisisKeywords, maxGapWords: 2)
        self.symptomHints = KeywordMatcher(keywords: config.symptomHints, prefixNegation: true)
        self.openingConcerns = KeywordMatcher(keywords: config.openingConcerns, prefixNegation: true)
        self.reading = AnswerReading(config: config, symptomHints: symptomHints, openingConcerns: openingConcerns)
        self.analyzer = analyzer
        self.knownIds = Set(config.effects.map(\.id))
        self.names = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.name) })
        self.keywords = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.keywords) })
        self.unasked = unasked
        self.locationWords = locationWords
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

    func handle(patientText: String) async -> Output {
        guard phase != .saved, phase != .emergencyEnded else {
            return Output(utterance: "", phase: phase)
        }
        // 위기 표현(자살 생각·자해·약 과다 복용)은 모델 판단 없이 안내하고 끝낸다. 말은 원문으로 남긴다
        // (2026-10-21 Foundation Models: "죽고 싶다는 생각이 들어요"를 되묻기만 해 기록 없이 사라졌다)
        if crisisDetector.matches(patientText) != nil {
            recordUnclearOther(patientText, name: rules.crisisName)
            return endWithEmergency(message: rules.crisisMessage)
        }
        if isEmergencyText(patientText) {
            return endWithEmergency()
        }
        if let pending = pendingEmergencyCheck {
            pendingEmergencyCheck = nil
            // 확인 질문에 아니라고 하면 하던 대로 잇는다. 그렇다고 하거나 분명하지 않으면 응급 안내로 끝낸다
            guard reading.soundsNegative(patientText) else { return endWithEmergency() }
            phase = pending.phase
            say(pending.output.utterance)
            return pending.output
        }
        let current = phase
        let before = ledger
        let (out, modelEmergency) = await respond(to: patientText)
        // 모델만 응급이라고 함 (응급 키워드·체온에는 안 걸림): 그 답의 기록을 검토 필요로 남기고 한 번 확인한다.
        // 모델의 응급 판단은 흔들려(증상 여럿 "토하고 입안도 아프고 손도 저려요"를 응급으로 봄) 바로 끝내지 않는다
        // (2026-10-21 Mac 평가, Foundation Models: 모델만 응급이라고 한 3번 중 1번이 거짓 응급, 2번은 혈변·실신)
        guard modelEmergency else { return out }
        markForReview(patientText, since: before)
        pendingEmergencyCheck = (out, phase)
        phase = current
        return Output(utterance: say(rules.confirmQuestion), phase: phase)
    }

    /// 답 한 턴을 기록하고 다음에 할 말을 정한다. 모델이 응급이라고 했는지도 함께 돌려준다 (검토 표시는 handle이 한다).
    /// 차례: 결과 얻기(짧은 답은 모델 없이) → 빠뜨린 증상 다시 묻기 → 기록 고치기 → 기록 → 꼬리질문·단계별 마무리 → 다음 질문
    private func respond(to patientText: String) async -> (output: Output, modelEmergency: Bool) {
        let current = phase
        let quick = quickResult(for: current, patientText: patientText)
        var result: TurnResult?
        if let quick {
            result = quick
        } else {
            result = await analyzedAnswer(during: current, patientText: patientText)
        }
        let modelEmergency = result?.emergencySignal == true
        result = await rechecked(result, during: current, patientText: patientText)
        if let analyzed = result {
            result?.mentions = correctedMentions(analyzed, during: current, patientText: patientText)
        }
        let before = ledger
        record(result?.mentions ?? [], during: current, patientText: patientText, since: before)
        if let followUp = openingFollowUp(result, during: current, patientText: patientText, since: before) {
            return (Output(utterance: say(followUp), phase: phase), modelEmergency)
        }
        // 꼬리질문의 답이면 첫 답과 합쳐 본다 ('피곤해요 / 일을 많이 해서요')
        let answerText = current == .opening ? [openingFirstAnswer, patientText].compactMap { $0 }.joined(separator: " / ") : patientText
        recordVerbatimOtherIfMissed(result, during: current, patientText: patientText, text: answerText,
                                    unchanged: ledger.sameRecords(as: before),
                                    modelAsked: quick == nil && result?.needsClarification == true)
        if let followUp = followUpCallReply(during: current, patientText: patientText, since: before) {
            return (Output(utterance: say(followUp), phase: phase), modelEmergency)
        }
        let settled = settleAnswer(result, during: current, patientText: patientText, since: before)
        if let question = settled.ask {
            return (Output(utterance: say(question), phase: phase), modelEmergency)
        }
        collectUnsettled(during: current, patientText: patientText, since: before)
        let utterance = await nextUtterance(after: current, quick: quick, patientText: patientText, since: before,
                                            prefix: settled.recordedPrefix)
        return (Output(utterance: utterance, phase: phase), modelEmergency)
    }

    /// 모델로 분석한다. 처음·그 밖에에서 모델이 증상을 기록하지 않고 맞장구만 쓰거나("열이 조금 나신다고 하셨습니다."),
    /// 증상 표현("머리가 좀 아파요")이나 목록 증상 낱말("설사", "올렸")이 있는데 아무것도 기록하지 않으면 한 번 더 분석한다
    /// (2026-10-13 실기기 평가 102회: 목록 낱말로 다시 분석할 턴 4개 중 3개가 실제로 놓친 증상)
    private func analyzedAnswer(during current: InterviewPhase, patientText: String) async -> TurnResult? {
        let result = await analyze(current, patientText: patientText)
        if let r = result, Self.acknowledgedWithoutRecord(r, during: current, patientText: patientText)
            || Self.missedSymptomHint(r, during: current, patientText: patientText,
                                      hints: config.symptomHints + config.effects.flatMap(\.keywords)) {
            return await analyze(current, patientText: patientText) ?? r
        }
        return result
    }

    /// 빠뜨린 증상을 그 증상 질문으로 다시 묻는다: 다른 항목을 묻다가 한 번복(recheckCorrection), 처음·그 밖에의 한 답 여러 증상(recheckSaidEffects)
    private func rechecked(_ result: TurnResult?, during current: InterviewPhase, patientText: String) async -> TurnResult? {
        var result = result
        if let analyzed = result, let recheck = await recheckCorrection(analyzed, during: current, patientText: patientText) {
            result?.mentions += recheck
        }
        if let analyzed = result, let rechecked = await recheckSaidEffects(analyzed, during: current, patientText: patientText) {
            result?.mentions = rechecked
        }
        return result
    }

    /// 모델이 낸 기록을 환자 말과 맞춰 고친다 (차례가 결과를 바꾸므로 이 순서를 지킨다)
    private func correctedMentions(_ analyzed: TurnResult, during current: InterviewPhase, patientText: String) -> [Mention] {
        var result = analyzed
        if case .slot(let key, .presence) = current {
            result.mentions = toCurrentSlot(result.mentions, key: key, patientText: patientText)
        }
        // 부위 질문의 답("얼굴 말고는 없어요")을 모델이 '없음'으로 읽어 있던 증상이 지워졌다 (2026-10-22 평가). 부위 질문에서는 유무를 바꾸지 않는다.
        // 그 항목 낱말을 직접 부정한 번복("이제 안 가려워요")만 받는다
        if case .slot(let key, .location) = current, let effect = config.effect(key),
           !(effect.said(in: patientText, minLength: 2)
             && KeywordMatcher(keywords: effect.keywords.filter { $0.count >= 2 }, prefixNegation: true).matches(patientText) == nil) {
            result.mentions.removeAll { $0.effectId == key && $0.presence != .present && $0.locations.isEmpty }
            for i in result.mentions.indices where result.mentions[i].effectId == key { result.mentions[i].presence = .present }
        }
        // 부위 질문의 답은 짧아 근거를 답 전체로 둔다. 모델이 "등이요"를 "등요"로 옮겨 적어 근거 확인에 걸리고 부위가 버려졌다 (2026-10-22 평가).
        // 부위 낱말은 Ledger가 환자 말에 있는지 따로 확인한다
        if case .slot(let key, .location) = current {
            for i in result.mentions.indices where result.mentions[i].effectId == key { result.mentions[i].quote = patientText }
        }
        if case .slot(let key, .presence) = current, let absent = absentByNormalAnswer(result, key: key, patientText: patientText) {
            result.mentions.append(absent)
        }
        // 줄었다는 말 없이 평소대로 한다는 답은 '없음' (모델이 "밥은 한 공기씩 먹어요"를 '있음'으로, "물도 잘 마셔요"를 빈 답으로 읽었다,
        // 2026-10-24 새 시나리오)
        if case .slot(let key, .presence) = current, let effect = config.effect(key), reading.saysUsual(effect, patientText) {
            result.mentions.removeAll { $0.effectId == key }
            result.mentions.append(Mention(effectId: key, presence: .absent, quote: patientText))
        }
        // 유무 질문에 모델이 낸 그 항목의 유무가 답의 말과 어긋나면 기록하지 않고 다시 묻는다 (잘못 남기느니 한 번 더 묻는다).
        // 이유 답("입이 아파서요")은 아래 reasonAnswer가 다시 채운다
        if case .slot(let key, .presence) = current {
            result.mentions.removeAll { $0.effectId == key && reading.contradicts($0.presence, patientText, for: key) }
        }
        // 유무 질문: 다 나았다는 답은 '없음', 앞부분에서 증상을 말하고 끝을 '괜찮아요'로 맺은 답은 '있음' (모델이 거꾸로 기록했다)
        if case .slot(let key, .presence) = current, let judged = presenceByClauses(key: key, patientText: patientText) {
            if !result.mentions.contains(where: { $0.effectId == key }) {
                result.mentions.append(Mention(effectId: key, presence: judged.presence, quote: patientText))
            }
            for i in result.mentions.indices where result.mentions[i].effectId == key {
                result.mentions[i].presence = judged.presence
                // 모델이 '없음'으로 읽어 부위가 비었으면 증상을 말한 절의 부위를 쓴다 ("팔은 가렵고" → 팔). 없으면 부위를 묻는다
                if judged.presence == .present, result.mentions[i].locations.isEmpty, let clause = judged.clause {
                    result.mentions[i].locations = locations(in: clause)
                }
            }
        }
        if let reason = reasonAnswer(result, during: current, patientText: patientText) {
            result.mentions.append(reason)
        }
        result.mentions = presentByPhrase(reassignedByKeywords(normalizedOthers(unevidencedAsOther(result.mentions, during: current, patientText: patientText),
                                                                                during: current, patientText: patientText),
                                                               during: current, patientText: patientText),
                                          during: current, patientText: patientText)
        result.mentions = otherClausesBesideListed(result.mentions, during: current, patientText: patientText)
        if current == .opening, unasked != nil {
            result.mentions = stoppedOverride(result.mentions, patientText: patientText)
        }
        // 지금 묻지 않은 항목의 '없음'은 환자가 그 항목 낱말을 말했을 때만 받는다. 모델이 상관없는 말("잠은 잘 자요",
        // "음 좀 어지러웠어요")을 근거로 식사를 '없음'으로 채워 식사 질문이 통째로 빠졌다 (2026-10-08 평가).
        // '있음'은 거르지 않는다: 낱말 목록이 초안이라 실제 증상을 놓칠 수 있고, '있음'은 횟수를 물으며 환자가 바로잡을 수 있다
        result.mentions.removeAll { m in
            m.presence == .absent && m.effectId != current.slotKey
                && config.effect(m.effectId).map { !$0.said(in: patientText) } == true
        }
        // 한 답 안에서 같은 항목이 있음·없음으로 함께 나오면 있음만 받는다. 차례로 넣으면 번복으로 처리돼 마지막 '없음'이 남고
        // 그 증상을 다시 묻지 않는다 ("어제 좀 토했어요, 그거 말고는 괜찮아요" → 구토 있음+없음, 2026-10-13 실기기 평가).
        // '있음'은 횟수를 물으며 환자가 바로잡을 수 있다. 근거 없는 '있음'(Ledger가 버림)으로 '없음'을 지우지 않는다
        let presentKeys = Set(result.mentions.filter { $0.presence == .present && Ledger.grounded($0.quote, in: patientText) }
            .map { Ledger.key(effectId: $0.effectId, otherName: $0.otherName) })
        result.mentions.removeAll { $0.presence == .absent && presentKeys.contains(Ledger.key(effectId: $0.effectId, otherName: $0.otherName)) }
        return result.mentions
    }

    /// 고친 기록을 Ledger에 넣고, 숫자 답을 꼬리질문 답으로 미리 채우고, 첫 질문 답을 컨디션 문장으로 남긴다
    private func record(_ mentions: [Mention], during current: InterviewPhase, patientText: String, since before: Ledger) {
        for mention in mentions {
            ledger.apply(mention, patientText: patientText, knownEffectIds: knownIds,
                         mayChangeRecorded: mayChangeRecorded(mention, during: current, patientText: patientText))
        }
        prefillNumber(from: patientText, since: before, during: current)
        if convertedToOther {
            for key in ledger.order where key.hasPrefix("other:") && before[key] == nil { ledger.markNeedsReview(key) }
            convertedToOther = false
        }
        // 첫 질문 답은 그대로 남긴다 (꼬리질문의 답이면 첫 답과 이어서). 다시 거는 통화는 컨디션을 묻지 않는다
        if current == .opening, unasked == nil {
            ledger.setConditionText([openingFirstAnswer, patientText].compactMap { $0 }.joined(separator: " / "))
        }
    }

    /// 첫 질문: 증상 표현이나 컨디션이 나쁘다는 말이 있고 목록 증상은 기록되지 않았으면 한 번 되묻는다. 되물을 말을 돌려준다
    /// ("피곤해요" → "어떤 점이 그러신지…". "보통이에요", "잠은 잘 자요"는 묻지 않음).
    /// 증상 표현이 있으면 모델이 되물어도 묻는다: "기침이 좀 나요 감기 기운인지"를 되묻기로 내 시작 시점을 묻지 않았다 (2026-10-22 평가)
    private func openingFollowUp(_ result: TurnResult?, during current: InterviewPhase, patientText: String, since before: Ledger) -> String? {
        guard current == .opening, openingFirstAnswer == nil, result?.needsClarification != true || symptomHints.matches(patientText) != nil,
              symptomHints.matches(patientText) != nil || openingConcerns.matches(patientText) != nil,
              !knownIds.contains(where: { ledger[$0]?.presence != before[$0]?.presence }),
              let followUp = openingFollowUpQuestion(patientText) else { return nil }
        openingFirstAnswer = patientText
        // 첫 답에서 생긴 기타 항목: 꼬리질문의 답에서 나온 이름 없는 기타는 여기에 붙인다 (같은 증상이 둘로 기록되지 않게)
        openingOtherName = ledger.order.first { $0.hasPrefix("other:") && before[$0] == nil }.flatMap { ledger[$0]?.otherName }
        return followUp
    }

    /// 다시 거는 통화의 첫 답. 되물을 말이 있으면 돌려준다
    /// - 말한 증상이 없는데 달라진 게 없다·없어졌다·모르겠다고 분명히 답하지도 않음("네"만, 분석 실패, 알아듣지 못한 답): 한 번 되묻는다
    /// - "글쎄요"면 달라진 점을 '모름'으로 남긴다
    /// - 분명히 달라진 게 없다면 '그 밖에'도 묻지 않는다 (첫 질문이 이미 물었다). 지난 통화에서 못 물은 항목이 있으면 묻고 '그 밖에'로 마무리
    private func followUpCallReply(during current: InterviewPhase, patientText: String, since before: Ledger) -> String? {
        guard current == .opening, let unasked else { return nil }
        // 증상이 없어졌다고만 말한 답("설사는 멈췄어요" → 이번 답으로 목록 증상 없음)은 알아들은 답이라 되묻지 않는다.
        // 연결어·숫자·나빠졌다는 말이 섞이면("멈췄는데 대신…") 놓친 증상이 있을 수 있어 되묻는다
        let mixed = Self.hasContrast(patientText)
            || NumberParser.hasNumber(patientText) || openingConcerns.matches(patientText) != nil
        let toldAbsent = !mixed && ledger.order.contains { key in
            knownIds.contains(key) && ledger[key]?.presence == .absent && before[key]?.presence != .absent
        }
        let unclear = reading.isUnclearChange(patientText), settled = unclear || reading.isUnchanged(patientText)
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
            return config.followUpCall.followUp
        }
        if unclear { recordUnclearChange(patientText) }
        // '그 밖에'는 달라진 게 없다·모르겠다고 분명히 답했을 때만 생략한다 (없어졌다는 답 뒤에는 한 번 묻는다)
        if !toldNewSymptom { otherAsked = settled && unasked.isEmpty }
        return nil
    }

    /// 단계마다의 마무리: '모름' 기록, 꼬리질문 답 기록, '그 밖에'의 기타 증상(언제부터를 물을 말은 ask로).
    /// recordedPrefix: '그 밖에' 기타 증상 기록 뒤 마무리 인사 앞에 붙이는 말
    private func settleAnswer(_ result: TurnResult?, during current: InterviewPhase, patientText: String,
                              since before: Ledger) -> (ask: String?, recordedPrefix: String?) {
        switch current {
        case .slot(let key, let step) where step != .detail
            && (reading.isUnknownAnswer(patientText) || (step == .presence && reading.isVagueAnswer(patientText))
                || (step == .location && reading.isNoLocation(patientText))):
            ledger.markUnknown(key, step: step, quote: patientText) // '모름' + 원문
        case .other where otherDetailKey == nil && reading.soundsUnsure(patientText) && ledger.sameRecords(as: before):
            // '그 밖에'에 "모르겠어요"·"그냥 그래요": 기타 '모름' + 원문으로 남기고 마무리 (증상 '있음'으로는 남기지 않는다)
            recordUnclearOther(patientText, name: config.otherUnclearName)
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
                return (nil, config.otherDetail.recorded)
            } else if let key = ledger.order.last(where: { $0.hasPrefix("other:") && before[$0] == nil }) {
                // 새 기타 증상: 무엇인지 이미 되물었거나 언제부터인지 이미 말했으면 바로 마무리, 아니면 시작 시점을 묻는다.
                // 모델이 증상으로 보지 않아 원문만 남긴 말(증상 표현 없음: "병원비 때문에 걱정이 많아요", "손주가 와서 바빴어요")에는
                // 시작 시점을 묻지 않는다 (2026-10-22 평가: 증상이 아닌 말 뒤에 "언제부터 그러셨어요?")
                let verbatimOnly = ledger[key]?.needsReview == true && symptomHints.matches(patientText) == nil
                if otherYesFollowedUp || reading.mentionsOnset(patientText) || verbatimOnly {
                    otherAsked = true
                    return (nil, config.otherDetail.recorded)
                }
                otherDetailKey = key
                return (config.otherDetail.question, nil)
            } else {
                // 분석이 실패하면 '그 밖에' 질문을 한 번 더 묻는다 (실패한 답의 증상을 버리지 않도록)
                otherAttempts += 1
                otherAsked = (result != nil && result?.needsClarification != true) || otherAttempts >= 2
                if result?.utterance == config.otherFollowUp { otherYesFollowedUp = true }
            }
        default:
            break
        }
        return (nil, nil)
    }

    /// 유무·부위 질문의 답이 분명하지 않으면(다시 묻게 됨) 답을 모아 둔다. 이 답으로 다른 증상이 기록됐으면 그 증상의 말이라 모으지 않는다
    private func collectUnsettled(during current: InterviewPhase, patientText: String, since before: Ledger) {
        guard case .slot(let key, let step) = current, step != .detail,
              ledger.order.allSatisfy({ $0 == key || (ledger[$0]?.presence == before[$0]?.presence && ledger[$0]?.locations == before[$0]?.locations) }),
              let entry = ledger[key], !entry.unknownSteps.contains(step),
              step == .presence ? (entry.presence == nil || entry.presence == .unclear) : entry.locations.isEmpty else { return }
        let said = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if !said.isEmpty { unsettledAnswers["\(key)|\(step)", default: []].append(said) }
    }

    /// 다음 질문과 그 앞에 붙이는 말 (첫 질문 뒤 넘어가는 말, 다시 거는 통화의 안내, 기타 증상 기록 인사)
    private func nextUtterance(after current: InterviewPhase, quick: TurnResult?, patientText: String, since before: Ledger,
                               prefix recordedPrefix: String?) async -> String {
        // 같은 항목을 다시 물을 때 모델이 쓴 문장은 쓰지 않고 설정 문구로 묻는다. 모델 문장은 설정 문구를 베끼거나(두 문장),
        // 원래 질문을 다시 쓰거나, 환자 말에 물음표만 붙인 것이었다 (2026-10-21 Foundation Models 평가: 되묻기 7번 모두)
        let followUp = quick?.utterance.isEmpty == false ? quick?.utterance : nil
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
            case (false, true): reading.isUnchanged(patientText) && !reading.isUnclearChange(patientText) ? f.unchanged : nil
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
        return utterance
    }

    /// 처음·그 밖에 질문에서 낱말이 꼭 있어야 하는 항목(keywordRequired: 저림·피부)을 환자 말에 그 낱말 없이 고르면 기타 증상으로 둔다
    /// (2026-10-22 평가: "허리가 아파서", "무릎이 쑤셔요", "어지러워요"를 저림으로, "옆구리가 결려요"를 피부로). 이름은 normalizedOthers가 원문으로 붙이고,
    /// 그 항목은 차례가 오면 그대로 묻는다
    private func unevidencedAsOther(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        guard phase == .opening || phase == .other else { return mentions }
        // 목록 낱말이 하나도 없고 증상 표현만 있는 말("요새 어지러워서 자꾸 누워 있어요", "머리가 핑 돌아요")은 어느 항목으로 골랐든 목록 밖 증상이다
        let nonListOnly = symptomHints.matches(patientText) != nil && !config.saysAnyEffect(in: patientText)
        return mentions.map { m in
            // '모름'(다시 확인해 이미 낮춘 것)은 그대로 둔다: 그 항목 차례에 다시 묻는다
            // 낱말을 부정한 말("다리가 저린 건 아니고 쑤셔요")은 근거가 아니다
            guard m.presence == .present, let effect = config.effect(m.effectId),
                  effect.keywordRequired == true || nonListOnly,
                  KeywordMatcher(keywords: effect.keywords, prefixNegation: true).matches(patientText) == nil else { return m }
            convertedToOther = true
            return Mention(effectId: "other", presence: m.presence, quote: m.quote)
        }
    }

    /// 모델이 고른 목록 증상의 낱말은 환자 말에 없고 다른 목록 증상 하나의 낱말만 있으면 그 증상으로 바꾼다
    /// ("요즘 입맛이 좀 없어요" → 모델은 구내염, 말한 낱말은 식사의 "입맛", 2026-10-17 실기기). 지금 묻는 항목의 답("네")은 그대로.
    /// 바꿀 증상을 고를 때는 한 글자 낱말("물", "먹", "토")을 쓰지 않는다 (다른 말 안에 흔히 들어 있다: "물을 마셔도", "토요일").
    /// 모델이 고른 증상을 지킬 때는 한 글자 낱말도 근거로 본다 ("물도 잘 안 넘어가고 입이 아파요"의 식사를 옮기지 않게)
    private func reassignedByKeywords(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        func said(_ id: String, minLength: Int) -> Bool {
            config.effect(id)?.said(in: patientText, minLength: minLength) == true
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
    /// 식사를 '없음'으로 기록해 식사 질문을 건너뛰었다 (2026-10-19 실기기). "입맛 없는 건 아니에요"처럼 부정하면 그대로 둔다.
    /// 다른 항목을 묻는 중에는 아직 묻지 않은 항목을 '있음'으로 만들지 않는다: 구토 답 "이틀 동안은 밥을 거의 못 먹었는데 지금은 나아져서"로
    /// 식사가 '있음'이 돼 식사 질문을 건너뛰고, 지금 상태("지금은 평소만큼 먹어요")를 묻지 못했다 (2026-10-20 Mac 평가 H16). 그 항목 차례에 직접 묻는다
    private func presentByPhrase(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        var result = mentions
        for effect in config.effects where reading.saysPresent(effect, patientText) {
            if let key = phase.slotKey, key != effect.id, ledger[effect.id]?.presence == nil { continue }
            result.removeAll { $0.effectId == effect.id && $0.presence != .present }
            if !result.contains(where: { $0.effectId == effect.id }) {
                result.append(Mention(effectId: effect.id, presence: .present, quote: patientText))
            }
        }
        return result
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
              before[key]?.presence != .present, let effect = config.effect(key),
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
        recordUnclearOther(patientText, name: config.followUpCall.unclearName)
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
                if step != .presence, current != .opening, current.slotKey != key, let effect = config.effect(key),
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

    /// 환자 말을 그대로 따라 쓴 것("딱히 어디가 불편한 건 아니에요")은 맞장구로 보지 않는다: 다시 분석해도 47번 중 44번이 빈 결과였다
    /// (2026-10-19 Mac 평가). 놓친 증상 낱말은 missedSymptomHint가, 놓친 목록 증상은 뒤의 항목 질문이 다시 묻는다
    static func acknowledgedWithoutRecord(_ result: TurnResult, during phase: InterviewPhase, patientText: String) -> Bool {
        switch phase {
        case .opening, .other: break
        default: return false
        }
        let u = result.utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.mentions.isEmpty, !result.needsClarification, !u.isEmpty, !u.contains("?") else { return false }
        let said = normalized(u), heard = normalized(patientText)
        return said.isEmpty || heard.isEmpty || !(said.contains(heard) || heard.contains(said))
    }

    /// 처음·그 밖에에서 이번 답으로 기록이 하나도 바뀌지 않았는데(모델이 비웠거나, 엉뚱한 항목에 붙여 막혔거나)
    /// 증상 표현이 부정 없이 있으면, 환자 말 그대로 기타 증상으로 기록하고 검토 필요로 둔다. 이름을 짓지 않는다 (의료진이 원문을 본다)
    private func recordVerbatimOtherIfMissed(_ result: TurnResult?, during phase: InterviewPhase, patientText: String, text: String,
                                             unchanged: Bool, modelAsked: Bool) {
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
        // 첫 질문의 꼬리질문("언제부터 그러셨어요?")에 답하면 모델은 시작 시점만 보고 되묻는다. 첫 답의 증상 표현은 그래도 남긴다
        // ("밤에 잠을 통 못 자요 / 주사 맞고부터요"가 기록 없이 사라졌다, 2026-10-22 평가)
        let keepAnyway = (phase == .other || (phase == .opening && openingFirstAnswer != nil)) && symptomHints.matches(text) != nil
        // '그 밖에'에서 모델이 되물은 말은 먼저 '모름'으로 남긴다: 되물은 답이 "없어요"·"네"면 처음 말이 사라졌다
        // ("이렇게 살아서 뭐하나 싶어요", 2026-10-21 Foundation Models 탐침). '있음'으로는 남기지 않는다
        if phase == .other, unchanged, modelAsked, !keepAnyway,
           !reading.soundsNegative(text), !reading.soundsUnsure(text), !reading.saysNormal(text) {
            recordUnclearOther(patientText, name: config.otherUnclearName)
            return
        }
        guard unchanged, result?.needsClarification != true || keepAnyway,
              symptomHints.matches(text) != nil
                || (phase == .other && !reading.soundsNegative(text) && !reading.soundsUnsure(text) && !reading.saysNormal(text))
                || (phase == .opening && unasked != nil && openingConcerns.matches(text) != nil) else { return }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        ledger.apply(Mention(effectId: "other", otherName: name, presence: .present, quote: patientText),
                     patientText: patientText, knownEffectIds: knownIds)
        ledger.markNeedsReview(Ledger.key(effectId: "other", otherName: name))
    }

    /// 모델만 응급이라고 본 답: 그 답으로 바뀐 기록을 검토 필요로 둔다 (통화는 그대로 이어 가고, 의료진이 기록에서 본다).
    /// 바뀐 기록이 없으면 환자 말을 '모름' 기타 항목(rules.reviewName)에 원문으로 남긴다: 모델 판단만으로 '있음' 증상을 만들지 않는다.
    /// 환자 화면(요약·기록)은 '있음'만 보여 이 항목은 보이지 않는다 (의료진 화면에서 검토 필요·모름을 보여 줄 것)
    private func markForReview(_ patientText: String, since before: Ledger) {
        let changed = ledger.changedKeys(since: before)
        guard changed.isEmpty else { return changed.forEach { ledger.markNeedsReview($0) } }
        recordUnclearOther(patientText, name: rules.reviewName)
    }

    /// 환자 말을 기타 항목(name)에 유무 '모름' + 원문으로 남긴다
    private func recordUnclearOther(_ patientText: String, name: String) {
        ledger.apply(Mention(effectId: "other", otherName: name, presence: .unclear, quote: patientText),
                     patientText: patientText, knownEffectIds: knownIds)
        ledger.markUnknown(Ledger.key(effectId: "other", otherName: name), step: .presence, quote: patientText)
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

    /// 처음·그 밖에 질문에서 환자 말에 목록 증상 낱말(두 글자 이상, 부정 아님)이 있는데 모델이 빠뜨린 증상은 그 증상을 묻는 질문으로 한 번 더
    /// 분석한다 (한 답에 여러 증상: "토하고 입안도 아프고 손도 저려요"의 구내염). 그렇게 '있음'이 나오면, 같은 말을 근거로 모델이 고른 다른 목록 증상 중
    /// 두 글자 이상 낱말 근거가 없는 것은 '모름'으로 바꾼다 (잘못 고른 ID: "오돌토돌…근질근질"을 구토로). 지우지 않아 실제 증상이었어도 잃지 않고,
    /// 그 항목 차례에 유무를 다시 묻는다. 판단은 모델이, 다시 물을지는 엔진이 정한다
    /// (2026-10-21 Foundation Models 평가: 지시문으로는 고쳐지지 않았다)
    private func recheckSaidEffects(_ result: TurnResult, during phase: InterviewPhase, patientText: String) async -> [Mention]? {
        switch phase {
        case .opening, .other: break
        default: return nil
        }
        let mentioned = Set(result.mentions.map(\.effectId))
        // 다시 물을 때는 그 낱말이 든 부분만 보여 준다: 증상 셋을 이은 답("속이 울렁거리고 등이 가렵고 변도 안 나와요")은
        // 다시 물어도 같은 증상만 골랐다. 근거(quote)는 원문의 일부라 Ledger가 그대로 확인한다
        let parts = AnswerReading.parts(patientText)
        let missed: [(effect: CareCallConfig.Effect, part: String)] = config.effects.compactMap { effect in
            guard !mentioned.contains(effect.id) else { return nil }
            let matcher = KeywordMatcher(keywords: effect.keywords.filter { $0.count >= 2 }, prefixNegation: true)
            guard matcher.matches(patientText) != nil else { return nil }
            return (effect, parts.first { matcher.matches($0) != nil }?.trimmingCharacters(in: .whitespaces) ?? patientText)
        }
        var added: [Mention] = []
        for (effect, part) in missed.prefix(3) {
            var request = AnalysisRequest(patientText: part, question: effect.ask, ledgerSummary: ledgerSummary())
            request.slotKey = effect.id
            request.step = .presence
            request.slotName = effect.name
            guard let recheck = try? await analyzer.analyze(request) else { continue }
            // 다시 물어도 근거 낱말 없는 다른 증상을 고르면("온몸이 근질근질해요" → 저림) 다시 묻는 그 증상의 답으로 본다
            added += toCurrentSlot(recheck.mentions, key: effect.id, patientText: part).filter { $0.effectId == effect.id && $0.presence == .present }
        }
        guard !added.isEmpty else { return nil }
        func evidenced(_ id: String) -> Bool {
            config.effect(id)?.said(in: patientText, minLength: 2) == true
        }
        // '모름'으로 바꾸는 것은 두 근거가 겹치고, 겹친 부분을 뺀 나머지에 그 증상 낱말이 하나도 없을 때만
        // ("토하고 입안도 아프고"의 구토는 나머지 "토하고"에 '토'가 있어 그대로, "혓바닥이 따갑고 쓰려요"의 저림은 나머지 "쓰려요"에 없어 '모름')
        func onlyFrom(_ m: Mention, _ new: Mention) -> Bool {
            let x = Self.normalized(m.quote), y = Self.normalized(new.quote)
            guard !x.isEmpty, !y.isEmpty, x.contains(y) || y.contains(x) else { return false }
            let rest = x.replacingOccurrences(of: y, with: "")
            return !(config.effect(m.effectId)?.keywords.contains { rest.contains(Self.normalized($0)) } ?? false)
        }
        let checked = result.mentions.map { m in
            guard knownIds.contains(m.effectId), m.presence == .present, !evidenced(m.effectId), added.contains(where: { onlyFrom(m, $0) })
            else { return m }
            var doubtful = m
            doubtful.presence = .unclear
            return doubtful
        }
        return checked + added
    }

    /// 유무 질문에 모델이 그 항목을 남기지 않았는데 답이 정상이라는 말로 끝나면 '없음'으로 본다 ("입 안은 멀쩡하고요", "피부도 깨끗하고요").
    /// 애매하면 남기지 않고 다시 묻는다: 정상이라는 말이 마지막 부분에 있어야 하고, 대조("깨끗한데 가려워요")·숫자·그 항목의 '있음' 표현·
    /// 증상 표현·다른 목록 증상 낱말이 있으면 보지 않는다 (2026-10-21 Foundation Models 평가: 모델이 빈 결과를 내 다시 물었다)
    private func absentByNormalAnswer(_ result: TurnResult, key: String, patientText: String) -> Mention? {
        guard !result.mentions.contains(where: { $0.effectId == key }), symptomHints.matches(patientText) == nil,
              !NumberParser.hasNumber(patientText),
              !Self.hasContrast(patientText),
              let effect = config.effect(key), !reading.saysPresent(effect, patientText),
              !config.effects.contains(where: { $0.id != key && $0.said(in: patientText, minLength: 2) })
        else { return nil }
        let parts = AnswerReading.parts(patientText)
        let last = parts.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? patientText
        let compact = Self.normalized(last)
        // 그 항목 낱말을 "안"으로 부정한 말도 정상이라는 말이다 ("아니요, 안 저려요"). "좀 저려요"는 아니다
        let ownKeywords = effect.keywords.filter { $0.count >= 2 }
        // 앞부분에서 그 항목을 부정 없이 말했으면("손은 저리고 발은 안 저려요") 마지막 부분이 정상이어도 보지 않는다
        let ownMatcher = KeywordMatcher(keywords: ownKeywords, prefixNegation: true)
        guard parts.dropLast().allSatisfy({ ownMatcher.matches($0) == nil || reading.soundsNegative($0) }) else { return nil }
        let ownNegated = ownKeywords.contains(where: last.contains) && ownMatcher.matches(last) == nil
        guard reading.soundsNegative(last) || ownNegated || config.normalWords.contains(where: { compact.contains(Self.normalized($0)) })
        else { return nil }
        return Mention(effectId: key, presence: .absent, quote: patientText)
    }

    /// 유무 질문에 모델이 지금 항목은 비우고 다른 목록 증상을 '있음'으로 골랐는데 환자 말에 그 증상 낱말이 하나도 없으면 지금 항목의 답으로 본다
    /// (2026-10-22 평가: 변비 질문에 "네 사흘째요"·"조금 나오긴 하는데 아직 시원하지 않아요"를 설사로 기록하고 변비를 다시 물었다)
    private func toCurrentSlot(_ mentions: [Mention], key: String, patientText: String) -> [Mention] {
        guard knownIds.contains(key), !mentions.contains(where: { $0.effectId == key }),
              let i = mentions.firstIndex(where: { m in
                  m.effectId != key && m.presence == .present
                      && config.effect(m.effectId).map { !$0.said(in: patientText) } == true
              }) else { return mentions }
        var moved = mentions
        moved[i].effectId = key
        return moved
    }

    /// 첫 질문 답에서 목록 증상을 기록했을 때, 목록 낱말이 없는 다른 부분에 증상 표현이 있으면 그 부분을 기타 증상으로 남긴다
    /// ("피곤하고 손도 저려요"의 피곤, "머리가 아프고 속도 메스꺼워요"의 두통 — 모델은 목록 증상만 기록했다, 2026-10-22 평가).
    /// 컨디션이 나쁘다는 말("힘들어요", "기운이 없어요")은 남기지 않는다. 모델이 기타를 이미 냈으면 손대지 않는다
    private func otherClausesBesideListed(_ mentions: [Mention], during phase: InterviewPhase, patientText: String) -> [Mention] {
        guard phase == .opening, mentions.contains(where: { knownIds.contains($0.effectId) && $0.presence == .present }),
              !mentions.contains(where: { $0.effectId == "other" }) else { return mentions }
        let parts = AnswerReading.parts(patientText)
            .map { $0.trimmingCharacters(in: .whitespaces.union(.punctuationCharacters)) }.filter { !$0.isEmpty }
        guard parts.count > 1 else { return mentions }
        return mentions + parts.filter { part in
            symptomHints.matches(part) != nil && openingConcerns.matches(part) == nil && !config.saysAnyEffect(in: part)
                // 주어 없는 "아파요"는 앞에서 말한 증상의 말이다 ("손발이 저리고 아파요"). "어지럽고"·"머리가 아프고"는 남긴다
                && !(!part.contains(" ") && ["아파", "아프", "아팠"].contains(where: part.contains))
        }.map { Mention(effectId: "other", otherName: $0, presence: .present, quote: $0) }
    }

    /// 유무 질문 답을 절로 나눠 본 유무. 모델이 자주 거꾸로 기록한 두 경우만 정하고, 그 밖에는 nil (모델 판단 그대로)
    /// (2026-10-22 평가: "지금은 다 괜찮아졌어요" → 있음, "손가락은 저리고 발가락은 괜찮아요"·"혓바늘이 났는데요 괜찮아요" → 없음)
    /// - 마지막 부분이 다 나았다는 말("약 먹고 멈췄어요", "지금은 괜찮아요", "이제 잘 봐요")이고 '아직·덜·좀' 같은 말이 없으면 없음.
    ///   사용자 결정(2026-10-21): 지금 상태 기준, 나아졌다고 분명히 말한 것만 없음, 좀 나아져도 아직 있으면 있음
    /// - 앞부분에서 그 항목 낱말을 부정 없이 말하고 마지막 부분이 괜찮다·정상이라는 말이면 있음
    private func presenceByClauses(key: String, patientText: String) -> (presence: MentionPresence, clause: String?)? {
        guard let effect = config.effect(key) else { return nil }
        // "따가운데요 괜찮아요"처럼 붙어 쓴 '-데요' 뒤도 절 경계로 본다 (띄어 쓴 "가려운 데는"은 아니다)
        let parts = AnswerReading.parts(patientText.replacingOccurrences(of: #"([가-힣])데요\s+"#, with: "$1데요,", options: .regularExpression))
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let last = parts.last else { return nil }
        let compact = Self.normalized(last)
        let lastNormal = reading.soundsNegative(last) || reading.saysNormal(last) || config.normalWords.contains { compact.contains(Self.normalized($0)) }
        if !Self.partialWords.contains(where: compact.contains),
           Self.resolvedWords.contains(where: { compact.contains($0) && !compact.contains("안" + $0) && !compact.contains("못" + $0) })
            || (Self.nowWords.contains(where: compact.contains) && lastNormal) {
            return (.absent, nil)
        }
        let own = KeywordMatcher(keywords: effect.keywords.filter { $0.count >= 2 }, prefixNegation: true)
        if parts.count > 1, lastNormal, let clause = parts.dropLast().first(where: {
            own.matches($0) != nil && !reading.soundsNegative($0) && !$0.contains("않") && $0.range(of: #"(^|\s)안\s"#, options: .regularExpression) == nil
        }) {
            return (.present, clause)
        }
        return nil
    }

    /// 절에 나온 부위 낱말. 겹치면 긴 낱말만 ("손가락" → 손가락, 손 아님), 나온 차례대로
    private func locations(in clause: String) -> [String] {
        let found = Set(locationWords.filter { clause.contains($0) })
        return found.filter { word in !found.contains { $0 != word && $0.contains(word) } }
            .sorted { clause.range(of: $0)!.lowerBound < clause.range(of: $1)!.lowerBound }
    }

    private static let resolvedWords = ["나았", "멈췄", "멎었", "그쳤", "없어졌", "괜찮아졌", "가라앉았", "들어갔", "아물었", "풀렸", "사라졌"]
    private static let nowWords = ["지금은", "이제", "요즘은", "뒤로는", "후로는"]
    private static let partialWords = ["아직", "덜", "조금", "좀", "가끔", "여전"]

    /// 첫 답을 한 번 되물을 말. 증상을 말했으면 시작 시점(이미 말했으면 nil: 되묻지 않는다), 컨디션이 나쁘다는 말뿐이면 무엇이 불편한지,
    /// 다시 거는 통화면 무엇이 달라졌는지. 막연한 "어떤 점이 그러신지 조금 더"는 무엇을 더 말할지 막막했다 (2026-10-22 사용자 피드백)
    private func openingFollowUpQuestion(_ patientText: String) -> String? {
        if symptomHints.matches(patientText) != nil { return reading.mentionsOnset(patientText) ? nil : config.otherDetail.question }
        return unasked == nil ? config.openingFollowUp : config.followUpCall.followUp
    }

    /// 짧고 분명한 답은 모델 없이 처리한다 (속도·재현성). 해당하지 않으면 nil → 모델 호출
    /// - 유무 단계: "네"는 있음, "아니요·없어요·괜찮아요"는 없음
    /// - 처음·그 밖에 질문의 "없어요" → 기록할 것 없음
    private func quickResult(for phase: InterviewPhase, patientText fullText: String) -> TurnResult? {
        // 앞에 붙는 "어", "응 어" 같은 말을 낱말 단위로 떼고 판정한다 ("응 어 있어" → "있어")
        let patientText = Self.withoutFillers(fullText, fillers: config.shortAnswers.fillers)
        let text = Self.normalized(patientText)
        let yes = reading.isShortYes(patientText), no = config.shortAnswers.no.contains(text)
        // "네? 뭐라고요?": 기록하지 않고 같은 질문을 다시 한다 (모델이 "네"를 보고 '있음'으로 남겼다, 2026-10-22 평가)
        if reading.isRepeatRequest(patientText), phase.asksQuestion {
            return TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: true,
                              emergencySignal: false, utterance: "")
        }
        switch phase {
        case .other where otherDetailKey != nil:
            // 기타 증상 꼬리질문의 답: 모델 없이 그대로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .slot(let key, .presence) where yes || no || reading.isClearNo(patientText, for: key):
            let entry = ledger[key]
            let mention = Mention(effectId: entry?.effectId ?? key, otherName: entry?.otherName,
                                  presence: yes && !no ? .present : .absent, quote: fullText)
            return TurnResult(mentions: [mention], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .other where yes: // "네"만: 무엇이 불편한지 되묻는다 (모델이 "네"를 증상으로 기록하지 않도록)
            return TurnResult(mentions: [], answeredCurrentSlot: false, needsClarification: true,
                              emergencySignal: false, utterance: config.otherFollowUp)
        case .slot(_, .presence) where reading.isUnknownAnswer(patientText) || reading.isVagueAnswer(patientText),
             .slot(_, .location) where reading.isUnknownAnswer(patientText) || reading.isNoLocation(patientText),
             .other where reading.isUnknownAnswer(patientText) || reading.isVagueAnswer(patientText):
            // "모르겠어요"·"그냥 그래요": 모델 없이 '모름' + 원문으로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .slot(_, .detail): // 횟수·시작 시점·지속 시간·섭취량: 모델 없이 환자 말 그대로 기록 (아래 switch)
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        // 달라진 게 없다는 답은 짧을 때만 모델 없이 처리한다 ("똑같아요", "없어요"). 긴 답은 증상이 섞였을 수 있어 모델이 먼저 본다
        // ("요즘 입맛이 좀 없어요"). 모델이 찾은 게 없고 달라진 게 없다는 말이면 그때 마친다 (handle)
        case .opening where unasked != nil && (yes || (reading.isUnchanged(patientText) && text.count <= 8) || reading.isUnclearChange(patientText)):
            // 다시 거는 통화: 달라진 게 없음·모르겠음 → 기록할 증상 없음 ("글쎄요"는 아래에서 '모름'으로 남긴다), "네"만 → 아래에서 되묻는다
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .opening where no || reading.isOpeningFine(patientText), .other where no:
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        default:
            return nil
        }
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

    /// 새 항목은 설정 파일 문구. 같은 항목을 다시 물을 때 엔진이 정한 꼬리질문(followUp)이 있으면 그것을 쓴다
    private func question(key: String, step: CareCallStep, followUp: String?) -> String {
        let model = followUp?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step {
        case .presence:
            if let model, !model.isEmpty { return model }
            return config.effect(key)?.ask ?? config.otherQuestion
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
        guard let entry = ledger[key], let effect = config.effect(key) else { return nil }
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

    private func endWithEmergency(message: String? = nil) -> Output {
        phase = .emergencyEnded
        let text = message ?? rules.message
        say(text)
        return Output(utterance: text, phase: phase)
    }

    /// 할 말을 마지막 질문으로 기억한다 (다음 분석 요청의 질문, 같은 질문 반복 판단에 쓴다)
    @discardableResult
    private func say(_ text: String) -> String {
        lastQuestion = text
        return text
    }

    // 다른 곳(Ledger·테스트)이 쓰는 이름. 판단은 AnswerReading에 있다
    static func withoutFillers(_ text: String, fillers: [String]) -> String { AnswerReading.withoutFillers(text, fillers: fillers) }
    static func hasContrast(_ text: String) -> Bool { AnswerReading.hasContrast(text) }
    static func normalized(_ s: String) -> String { AnswerReading.normalized(s) }
}
