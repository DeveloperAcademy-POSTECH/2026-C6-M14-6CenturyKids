//
//  AnswerReading.swift
//  ToDoc
//
//  Created by seokho on 10/23/26.
//

import Foundation

/// 환자 답 한 마디의 말 판단: 없다는 말인지, 애매한 답인지, 되묻는 말인지 등.
/// 설정 문구·낱말과 증상 표현 판별기만 보고 대화 상태(기록·단계)는 보지 않는다. 판단을 어떻게 쓸지는 InterviewEngine이 정한다
struct AnswerReading {
    let config: CareCallConfig
    let symptomHints: KeywordMatcher
    let openingConcerns: KeywordMatcher
    /// 몸 부위 사전 낱말 (부위 주어로 증상을 가릴 때)
    let locationWords: [String]

    /// "잘 모르겠어요", "기억이 안 나요" 같은 답. 숫자·없음 표현·연결어·증상 낱말이 함께 있으면 아니다
    /// ("모르겠는데 3번쯤", "잘 모르겠지만 좀 메스꺼웠어요"는 모델이 본다)
    func isUnknownAnswer(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        guard config.unknownAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(text), !soundsNegative(text) else { return false }
        if Self.continuesAfterContrast(text) { return false }
        return !config.saysAnyEffect(in: text) && symptomHints.matches(text) == nil
    }

    /// 유무 질문에 있다고도 없다고도 하지 않은 답 ("그냥 좀 그래요", "글쎄요"). 있다·없다는 말, 숫자, 연결어, 증상 낱말·표현이
    /// 함께 있으면 아니다 ("그냥 그래요, 없어요", "좀 그래요, 속이 메스꺼워요"는 지금처럼 판단한다)
    func isVagueAnswer(_ text: String) -> Bool {
        let t = Self.withoutFillers(text, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard config.vagueAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(t), !soundsNegative(t),
              !["있", "했"].contains(where: compact.contains), !saysNormal(t),
              !config.normalWords.contains(where: { compact.contains(Self.normalized($0)) }),
              !config.shortAnswers.yes.contains(where: { compact.hasPrefix(Self.normalized($0)) }) else { return false }
        if Self.continuesAfterContrast(t) { return false }
        return !config.saysAnyEffect(in: t) && symptomHints.matches(t) == nil
    }

    /// 모르겠다·애매하다는 말만 있는 답 (숫자는 섞여도 된다). '그 밖에'에서 이런 답을 증상 '있음'으로 남기지 않고 '모름' + 원문으로 남길 때 쓴다.
    /// 증상 낱말·표현이나 없다는 말이 있으면 아니다 ("모르겠는데 머리가 아파요"는 증상으로, "모르겠어요 없는 것 같아요"는 없음으로)
    func soundsUnsure(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        guard (config.unknownAnswers + config.vagueAnswers).contains(where: { compact.contains(Self.normalized($0)) }),
              !soundsNegative(text), symptomHints.matches(text) == nil else { return false }
        return !config.saysAnyEffect(in: text)
    }

    /// 없다는 뜻이 담긴 답 ("없어요", "딱히 없는 것 같아요", "괜찮아요", "아니요 그냥 그래요")
    /// "읎"은 사투리 "읎어요·읎심더"
    func soundsNegative(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        return ["없", "읎", "괜찮", "아니", "아뇨"].contains(where: compact.contains)
            || config.noSuffixes.contains(where: { compact.hasSuffix(Self.normalized($0)) })
            || config.shortAnswers.no.contains(Self.normalized(Self.withoutFillers(text, fillers: config.shortAnswers.fillers)))
    }

    /// '…이/가 (…) 없어요'의 주어가 이 항목 말이 아님 ("다리에 힘이 하나도 없어요", "밤에 잠이 통 없어요", 구토 질문에 "발에 감각이 하나도 없어요").
    /// 그냥 없다는 답으로 읽으면 다른 증상이 '없음'으로 사라졌다 (2026-10-24 확인 세트). "헌 데가 없어요", "토한 적이 없어요",
    /// "별 이상이 없어요"처럼 가리키는 말이 주어이거나 이 항목 낱말이 주어("변비가 없어요")면 그냥 없다는 답이다
    func negatesOtherThing(_ text: String, for key: String) -> Bool {
        let own = config.effect(key)?.keywords ?? []
        let pointers: Set<String> = ["게", "거", "것", "데", "적", "곳", "부분", "이상", "문제", "증상", "별일", "아무것", "많", "같", "깊"]
        return Self.parts(text).contains { clause in
            soundsNegative(clause) && clause.matches(of: /([가-힣]+)(?:이|가)\s/).contains { m in
                let noun = String(m.1)
                return !pointers.contains(noun) && !own.contains { $0.contains(noun) || noun.contains($0) }
            }
        }
    }

    /// 다시 묻는 말 ("어떤 거 말씀이세요?", "뭘요?"). 유무 질문 답으로 남기지 않는다
    static func asksBack(_ text: String) -> Bool {
        text.contains("말씀") || text.trimmingCharacters(in: .whitespaces).hasSuffix("?")
    }

    /// 절마다 없다·괜찮다·정상이라는 말뿐인 답 ("다른 데는 멀쩡해요", "몸은 대체로 편안해요"). 증상 표현이 있으면 아니다
    func soundsFine(_ text: String) -> Bool {
        symptomHints.matches(text) == nil && Self.parts(text).allSatisfy { clause in
            soundsNegative(clause) || saysNormal(clause) || config.normalWords.contains { Self.normalized(clause).contains(Self.normalized($0)) }
        }
    }

    /// 첫 답·'그 밖에' 답이 증상을 말한 것인지: 증상 표현 낱말이 있거나, 몸 부위가 주어로 나온다("눈이 자꾸 침침해요", "귀에서 삐 소리가 나요",
    /// "다리에 쥐가 나요"). 증상 표현 낱말로만 가려 "눈이 침침해요"에 시작 시점을 묻지 않았다 (2026-10-24 확인 세트).
    /// 부위 낱말만 든 말("머리 염색을 했어요", "손주들이 왔어요", "목요일에 병원 가요")과 없다는 절("눈은 괜찮아요")은 아니다
    func saysSymptom(_ text: String) -> Bool {
        if symptomHints.matches(text) != nil { return true }
        return AnswerReading.parts(text).contains { clause in
            !soundsNegative(clause) && !saysNormal(clause) && locationWords.contains { word in
                clause.range(of: NSRegularExpression.escapedPattern(for: word) + #"(?:이|가|은|는|에서|에)(?=\s|$)"#, options: .regularExpression) != nil
            }
        }
    }

    /// '그 밖에' 답이 더 말할 게 없다는 끝맺음인지 (config.closingEndings). 증상 표현·항목 낱말·몸 부위 낱말이 있으면 아니다
    func isClosing(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        return config.closingEndings.contains { compact.hasSuffix(Self.normalized($0)) }
            && symptomHints.matches(text) == nil && !config.saysAnyEffect(in: text) && !locationWords.contains { text.contains($0) }
    }

    /// 어느 항목의 정상이라는 말로 끝남 ("변은 잘 나와요", "평소만큼 먹어요"). '그 밖에' 답을 기타 증상으로 남기지 않을 때 쓴다
    func saysNormal(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        return config.effects.flatMap { $0.absentPhrases ?? [] }.contains { compact.hasSuffix(Self.normalized($0)) }
            // 다 나았다는 말로 끝남 ("쑤시던 건 다 나았어요", "결리던 것도 풀렸어요"). 아직·또·다시·안 나·덜이 있으면 아니다
            || (compact.range(of: #"(나았|풀렸|없어졌|괜찮아졌|가라앉았|멈췄|그쳤|빠졌)(어요|습니다|어|네요)?$"#, options: .regularExpression) != nil
                && !["아직", "또", "다시", "안나", "덜"].contains(where: compact.contains))
    }

    /// 유무 질문의 답과 모델이 낸 그 항목의 유무가 어긋남 (Foundation Models, 2026-10-21 Mac 평가):
    /// - '없음'인데 없다는 말 없이 잘 안 된다는 말만 있음 ("잘 안 나와요")
    /// - '있음'인데 그 항목 낱말은 없고 다른 증상 낱말만 있음 (구내염 질문에 "입맛이 없어서 조금밖에 못 먹어요"). "네"로 시작하면 그 항목의 답이다
    func contradicts(_ presence: MentionPresence, _ patientText: String, for key: String) -> Bool {
        switch presence {
        case .absent:
            return ["잘안", "잘못", "안좋"].contains(where: Self.normalized(patientText).contains) && !soundsNegative(patientText)
        case .present:
            guard let effect = config.effect(key), !effect.said(in: patientText),
                  let first = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers).split(separator: " ").first,
                  !config.shortAnswers.yes.contains(Self.normalized(String(first))) else { return false }
            return config.effects.contains { $0.id != key && $0.said(in: patientText, minLength: 2) }
        default:
            return false
        }
    }

    /// answering: 이 항목을 묻는 중 (answerPhrases도 본다)
    func saysPresent(_ effect: CareCallConfig.Effect, _ patientText: String, answering: Bool = false) -> Bool {
        ((effect.presentPhrases ?? []) + (answering ? effect.answerPhrases ?? [] : [])).contains { phrase in
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

    /// 이 항목을 물을 때 줄었다는 말 없이 평소대로 한다는 답 (effect.usualAnswer). 증상 표현·대조가 있으면 아니다
    func saysUsual(_ effect: CareCallConfig.Effect, _ patientText: String) -> Bool {
        guard let usual = effect.usualAnswer else { return false }
        let t = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let compact = Self.normalized(t)
        func ends(with list: [String]) -> Bool { list.contains { compact.hasSuffix(Self.normalized($0)) } }
        // 모델은 평소와 같다는 답("식사는 평소대로 해요", "입맛은 그대로예요")에 아무것도 남기지 않아 다시 물었다 (2026-11-03 보류 세트).
        // 그대로인 것이 줄어든 상태일 수 있는 답은 보지 않는다: 풀어 말한 답("물이 안 넘어가는 건 여전해요"), 다른 날에 견준 답("어제랑 똑같아요")
        let same = ends(with: usual.sameEndings ?? []) && t.firstMatch(of: /(건|게|거|것은|것도|것이)\s/) == nil
            && !(usual.sameUnless ?? []).contains { compact.contains(Self.normalized($0)) }
        return (ends(with: usual.endings) || same)
            && !usual.unless.contains { compact.contains(Self.normalized($0)) }
            && t.firstMatch(of: /[가-힣]만\s/) == nil
            && symptomHints.matches(t) == nil && !Self.hasContrast(t) && !saysPresent(effect, t, answering: true)
    }

    /// 유무 질문에 분명한 '없음' ("아니요 변 잘 봤어요", "설사는 안 했어요"): 없음 표현으로 시작하거나 끝나고,
    /// 지금 항목 밖의 증상 낱말·증상 표현·숫자·연결어("근데", "는데", "지만")가 없을 때만. 하나라도 있으면 모델이 판단
    func isClearNo(_ patientText: String, for key: String) -> Bool {
        guard !key.hasPrefix("other:") else { return false }
        // "입맛이 없어요"는 '없어요'로 끝나도 식사 증상이 있다는 말이다
        let effect = config.effect(key)
        if let effect, saysPresent(effect, patientText, answering: true) { return false }
        let t = patientText.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let compact = Self.normalized(t)
        // 없음 표현으로 시작만 하면 뒷말이 번복일 수 있어("아니요 설사 맞아요 설사 했어요") 없음 표현 하나뿐일 때만 인정
        guard config.noPrefixes.contains(where: { compact == Self.normalized($0) })
                || (config.noSuffixes + (effect?.absentPhrases ?? [])).contains(where: { compact.hasSuffix(Self.normalized($0)) })
        else { return false }
        if Self.hasContrast(t) || t.contains("그리고") { return false }
        if NumberParser.hasNumber(t) { return false }
        if config.effects.contains(where: { $0.id != key && $0.said(in: t) }) { return false }
        if negatesOtherThing(t, for: key) { return false }
        return symptomHints.matches(t) == nil
    }

    /// 다시 거는 통화의 첫 질문에 "글쎄요"·"잘 모르겠어요" (증상 낱말·숫자·연결어가 있으면 모델이 본다)
    func isUnclearChange(_ patientText: String) -> Bool {
        // 나빠졌다는 말이 섞이면 모델이 본다 ("글쎄요, 좀 안 좋아진 것 같기도 하고요")
        guard openingConcerns.matches(patientText) == nil else { return false }
        if isUnknownAnswer(patientText) { return true }
        let compact = Self.normalized(patientText)
        // 숫자가 섞이면 모델이 본다 ("글쎄요 두 번?"). 모델이 찾은 게 없으면 원문은 handle에서 남긴다
        guard config.vagueAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(patientText),
              !Self.continuesAfterContrast(patientText) else { return false }
        return !config.saysAnyEffect(in: patientText) && symptomHints.matches(patientText) == nil
    }

    /// 다시 거는 통화의 첫 질문에 달라진 게 없다는 답 ("똑같아요", "그대로예요", "없어요", "괜찮아요").
    /// 연결어·숫자·증상 낱말·증상 표현이 있으면 아니다 ("똑같은데 어제 설사를 했어요"는 모델이 본다)
    func isUnchanged(_ patientText: String) -> Bool {
        let t = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard soundsNegative(t) || config.followUpCall.unchangedAnswers.contains(where: { compact.contains(Self.normalized($0)) })
        else { return false }
        if Self.continuesAfterContrast(t) { return false }
        // "똑같지 않아요", "그대로가 아니에요": 달라졌다는 뜻이라 모델이 본다 (띄어쓰기 없이 비교)
        // "아무렇지 않아요"는 그대로라는 말이다
        if ["지않", "진않", "가아니", "이아니", "게아니"].contains(where: compact.replacingOccurrences(of: "아무렇지", with: "").contains) { return false }
        if NumberParser.hasNumber(t) { return false }
        if config.saysAnyEffect(in: t) { return false }
        return symptomHints.matches(t) == nil && openingConcerns.matches(t) == nil
    }

    /// 첫 질문의 답이 '좋아요·보통이에요' 류이고 증상 표현·나쁘다는 말·연결어("좋긴 한데 피곤해요")가 없으면 true (모델 생략)
    func isOpeningFine(_ patientText: String) -> Bool {
        let t = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard config.openingFine.contains(where: { compact.contains(Self.normalized($0)) }) else { return false }
        if ["근데", "그런데", "는데", "지만", "한데", "긴 한데"].contains(where: { t.contains($0) }) { return false }
        // 증상 낱말이 있으면 모델이 본다 ("어제 좀 토했어요, 그거 말고는 괜찮아요")
        if config.saysAnyEffect(in: t) { return false }
        return symptomHints.matches(t) == nil && openingConcerns.matches(t) == nil
    }

    /// 음성 인식이 "네네"·"예 예"로 받아 적은 답도 "네"다 (2026-10-29 팀 테스트: 저장 내용이 "네네"로 남았다)
    func isShortYes(_ patientText: String) -> Bool {
        let t = Self.normalized(patientText)
        return config.shortAnswers.yes.contains(t)
            || (t.count >= 2 && Set(t).count == 1 && ["네", "예", "응"].contains(String(t.prefix(1))))
    }

    /// 두 증상을 함께 묻는 항목(구토·메스꺼움)에 한쪽만 부정하고 다른 불편을 말한 답 ("토는 안했는데 속은 좀 안좋아요").
    /// 다른 쪽 증상(메스꺼움)이라고 단정하지 않고 '모름' + 원문으로 남긴다. 다시 물으면 "토 안했다니까요"가 됐다 (2026-10-29 팀 테스트)
    /// 불편을 말한 절은 증상 낱말 없이 없다·괜찮다는 말도 아닌 절이다 ("속이 더부룩해요"). symptomHints에 "쓰라" 같은 낱말을 넣으면
    /// 첫 답 "잇몸이 붓고 쓰라려요"가 '그 밖에'로도 저장됐다 (2026-10-30 회귀 세트)
    func deniesOnePartButComplains(_ text: String, for key: String) -> Bool {
        guard let said = partsSaid(text, for: key), said.denied, !said.affirmed else { return false }
        return Self.parts(text).contains { clause in
            guard !config.saysAnyEffect(in: clause) else { return false }
            if symptomHints.matches(clause) != nil || openingConcerns.matches(clause) != nil { return true }
            let compact = Self.normalized(clause)
            return !soundsNegative(clause) && !saysNormal(clause) && !config.normalWords.contains { compact.contains(Self.normalized($0)) }
        }
    }

    /// 두 증상을 함께 묻는 항목에 한쪽은 부정하고 다른 쪽 낱말은 부정 없이 말한 답 ("구토는 안 했고 속이 울렁거려요").
    /// 환자가 증상 낱말로 직접 말해 '있음'이다. 모델이 '없음'으로 읽었다 (2026-10-30 확인 세트)
    func deniesOnePartAffirmsOther(_ text: String, for key: String) -> Bool {
        guard let said = partsSaid(text, for: key) else { return false }
        return said.denied && said.affirmed
    }

    /// 두 증상을 함께 묻는 항목(details 중 keywords가 따로 있는 것이 둘 이상)에서, 낱말은 나왔지만 부정한 쪽이 있는지·부정 없이 말한 쪽이 있는지
    private func partsSaid(_ text: String, for key: String) -> (denied: Bool, affirmed: Bool)? {
        guard let parts = config.effect(key)?.details.compactMap(\.keywords), parts.count >= 2 else { return nil }
        let affirmed = { (words: [String]) in CareCallConfig.Effect.said(words, in: text) }
        return (parts.contains { words in words.contains(where: text.contains) && !affirmed(words) }, parts.contains(where: affirmed))
    }

    /// 질문을 다시 해 달라는 말 ("네? 뭐라고요?", "잘 안 들려요 다시 말해 주세요"). 답 전체가 되묻는 말과 "네"·"죄송한데" 같은 말뿐일 때만.
    /// 다른 말이 섞이면 모델이 본다: 낱말이 들어 있기만 해도 보면 "밥이 잘 안 들어가요", "귀가 잘 안 들려요",
    /// "뭐라고 해야 하나, 속이 울렁거려요"가 되묻기로 버려졌다 (2026-10-22 보안 리뷰·평가)
    func isRepeatRequest(_ text: String) -> Bool {
        var rest = Self.normalized(Self.withoutFillers(text, fillers: config.shortAnswers.fillers))
        var found = false
        for phrase in config.repeatRequests.map(Self.normalized).sorted(by: { $0.count > $1.count }) where rest.contains(phrase) {
            rest = rest.replacingOccurrences(of: phrase, with: "")
            found = true
        }
        for word in Self.repeatCourtesy { rest = rest.replacingOccurrences(of: word, with: "") }
        return found && rest.isEmpty
    }

    /// 부위 질문에 "없어요"·"딱히 없어요"·"어디라고 딱히 없어요"만: 부위는 '모름'으로 둔다 (유무를 뒤집지 않는다).
    /// 부위가 섞인 답("손은 괜찮고 발이 저려요", "얼굴 말고는 없어요")은 모델이 부위를 뽑는다 (2026-10-22 보안 리뷰)
    func isNoLocation(_ text: String) -> Bool {
        let compact = Self.normalized(Self.withoutFillers(text, fillers: config.shortAnswers.fillers))
        return compact.range(of: #"^(아니요|아뇨|아니)?(딱히|따로|특별히|별로)?(어디|아무\s*데|그런\s*데|그런\s*곳|데|곳|부위)?(라고는|라고|는|도|가|은)?(딱히|따로|특별히|별로)?(없어요|없어|없습니다|없었어요|없는것같아요|몰라요|모르겠어요|잘모르겠어요)$"#,
                             options: .regularExpression) != nil
    }

    /// 언제부터인지 이미 말했는지 ("어제부터 머리가 아파요", "사흘째", "2주 전부터")
    func mentionsOnset(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        return config.onsetWords.contains { compact.contains(Self.normalized($0)) }
            || text.range(of: #"(\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열)\s*(일|주|주일|달|개월|년|시간)\s*(전|째|넘게)"#,
                          options: .regularExpression) != nil
    }

    /// 앞쪽의 군말 낱말을 뗀다. 띄어쓰기로 나뉜 낱말 전체가 목록과 같을 때만 떼고, 남는 낱말이 없으면 원문 그대로
    /// ("음 아프지 않아" → "아프지 않아", "아프지 않아" → 그대로, "응" → 그대로)
    static func withoutFillers(_ text: String, fillers: [String]) -> String {
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let bare = { (w: String) in w.trimmingCharacters(in: .punctuationCharacters) }
        while words.count > 1, let first = words.first, fillers.contains(bare(first)) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    /// 뒤에 다른 말이 올 수 있는 대조 표현: "~데"·"~데요"(깨끗한데·괜찮은데·저리긴 한데요 — "는데"만 보면 "한데"를, 끝 경계만 보면 "한데요,"를 놓친다),
    /// "~지만", "근데", "그래도", "대신"
    /// 답을 절로 나눈다: 쉼표·마침표·"~는데/~지만" 뒤와 "~고 " 뒤에서 끊는다 ("속이 울렁거리고 등이 가렵고 변도 안 나와요" → 세 절)
    static func parts(_ text: String) -> [String] {
        // "토는 안 했어요 근데 속이 불편해요"도 두 절 (2026-10-30 확인 세트)
        KeywordMatcher.clauses(text.replacingOccurrences(of: #"고\s+"#, with: "고,", options: .regularExpression)
            .replacingOccurrences(of: #"\s(근데|그런데)\s"#, with: ",", options: .regularExpression))
    }

    /// 연결어("근데", "는데", "지만") 뒤에 다른 말이 이어지는지. 답 끝의 "~데(요)"("없는데", "잘 모르겠는데요")는 뒤에 말이 없어 보지 않는다
    /// (2026-10-29 팀 테스트: 다시 거는 통화에 "없는데"를 달라진 게 없다는 답으로 보지 않아 "어떤 점이 달라지셨는지" 되물었다).
    /// 뒤에 군말 하나만 붙어도("모르겠는데요 잘", "없는데 진짜") 끝으로 본다 (2026-10-30 확인 세트). "없는데 설사"처럼 다른 말은 이어지는 말이다
    static func continuesAfterContrast(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacing(/데요?(?:[\s,]+(?:잘|좀|음|뭐|그냥|진짜|정말|참|아주))?$/, with: "")
        return ["근데", "그런데", "는데", "지만", "한데"].contains(where: t.contains)
    }

    static func hasContrast(_ text: String) -> Bool {
        text.range(of: #"[가-힣]데요?(?=[\s,.?!]|$)|지만|그래도|대신"#, options: .regularExpression) != nil
    }

    /// 되묻는 말 앞뒤에 붙어도 되는 말 ("죄송한데 다시 말씀해 주시겠어요?")
    static let repeatCourtesy = ["죄송한데", "죄송하지만", "죄송해요", "저기요", "잠깐만요", "네", "예", "좀"]

    /// 띄어쓰기·문장 부호를 뺀 말 (낱말 비교용)
    static func normalized(_ s: String) -> String { String(s.filter { !$0.isWhitespace && !$0.isPunctuation }) }
}
