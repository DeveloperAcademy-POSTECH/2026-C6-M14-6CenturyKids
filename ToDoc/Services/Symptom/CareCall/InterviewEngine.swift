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
    /// '그 밖에'에 "네"만 답해 무엇인지 이미 되물었음 (그 답에는 또 묻지 않는다)
    private var otherYesFollowedUp = false
    /// 첫 질문에 꼬리질문을 했으면 그 첫 답
    private var openingFirstAnswer: String?
    private var openingOtherName: String?
    private var lastQuestion: String

    init(config: CareCallConfig, rules: EmergencyRules, analyzer: any CareCallAI) {
        self.config = config
        self.rules = rules
        self.detector = KeywordMatcher(keywords: rules.keywords)
        self.symptomHints = KeywordMatcher(keywords: config.symptomHints, prefixNegation: true)
        self.openingConcerns = KeywordMatcher(keywords: config.openingConcerns, prefixNegation: true)
        self.analyzer = analyzer
        self.knownIds = Set(config.effects.map(\.id))
        self.names = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.name) })
        self.keywords = Dictionary(uniqueKeysWithValues: config.effects.map { ($0.id, $0.keywords) })
        self.lastQuestion = config.openingQuestion
    }

    func start() -> Output {
        say(config.openingQuestion)
        return Output(utterance: config.openingQuestion, phase: phase)
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
            result?.mentions = normalizedOthers(mentions, during: current, patientText: patientText)
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
        // 첫 질문 답은 그대로 남긴다 (꼬리질문의 답이면 첫 답과 이어서)
        if current == .opening {
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

        switch current {
        case .slot(let key, let step) where step != .detail && isUnknownAnswer(patientText):
            ledger.markUnknown(key, step: step, quote: patientText)
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

        let followUp = Self.validFollowUp(result?.utterance, patientText: patientText)
        let recordedThisTurn = !ledger.sameRecords(as: before) // advance()가 '물음' 표시를 남기기 전에 본다
        var utterance = await advance(from: current, followUp: followUp)
        if current == .opening {
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
            switch SlotPlanner.next(ledger: ledger, config: config, otherAsked: otherAsked) {
            case .slot(let key, let step):
                guard ledger.markAsked(key, step: step) else { continue } // 한도 초과 → 다음 항목
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
        guard unchanged, result?.needsClarification != true,
              symptomHints.matches(text) != nil || (phase == .other && !soundsNegative(text) && !isUnknownAnswer(text)) else { return }
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
              NumberParser.numbers(in: text).isEmpty, !soundsNegative(text) else { return false }
        if ["는데", "지만", "근데", "그런데"].contains(where: text.contains) { return false }
        return !config.effects.flatMap(\.keywords).contains(where: text.contains) && symptomHints.matches(text) == nil
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
        case .slot(_, .presence) where isUnknownAnswer(patientText),
             .slot(_, .location) where isUnknownAnswer(patientText),
             .other where isUnknownAnswer(patientText): // "모르겠어요": 모델 없이 '모름'으로 기록 (아래 switch), 그 밖에는 없음
            return TurnResult(mentions: [], answeredCurrentSlot: true, needsClarification: false,
                              emergencySignal: false, utterance: "")
        case .slot(_, .detail): // 횟수·시작 시점·지속 시간·섭취량: 모델 없이 환자 말 그대로 기록 (아래 switch)
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
        let t = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let compact = Self.normalized(t)
        // 없음 표현으로 시작만 하면 뒷말이 번복일 수 있어("아니요 설사 맞아요 설사 했어요") 없음 표현 하나뿐일 때만 인정
        guard config.noPrefixes.contains(where: { compact == Self.normalized($0) })
                || config.noSuffixes.contains(where: { compact.hasSuffix(Self.normalized($0)) }) else { return false }
        if ["근데", "그런데", "는데", "지만", "그리고", "대신"].contains(where: { t.contains($0) }) { return false }
        if !NumberParser.numbers(in: t).isEmpty { return false }
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
