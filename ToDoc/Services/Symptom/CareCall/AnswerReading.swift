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

    /// "잘 모르겠어요", "기억이 안 나요" 같은 답. 숫자·없음 표현·연결어·증상 낱말이 함께 있으면 아니다
    /// ("모르겠는데 3번쯤", "잘 모르겠지만 좀 메스꺼웠어요"는 모델이 본다)
    func isUnknownAnswer(_ text: String) -> Bool {
        let compact = Self.normalized(text)
        guard config.unknownAnswers.contains(where: { compact.contains(Self.normalized($0)) }),
              !NumberParser.hasNumber(text), !soundsNegative(text) else { return false }
        if ["는데", "지만", "근데", "그런데"].contains(where: text.contains) { return false }
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
        if ["는데", "지만", "근데", "그런데"].contains(where: t.contains) { return false }
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
        return usual.endings.contains { compact.hasSuffix(Self.normalized($0)) }
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
              !["는데", "지만", "근데", "그런데"].contains(where: patientText.contains) else { return false }
        return !config.saysAnyEffect(in: patientText) && symptomHints.matches(patientText) == nil
    }

    /// 다시 거는 통화의 첫 질문에 달라진 게 없다는 답 ("똑같아요", "그대로예요", "없어요", "괜찮아요").
    /// 연결어·숫자·증상 낱말·증상 표현이 있으면 아니다 ("똑같은데 어제 설사를 했어요"는 모델이 본다)
    func isUnchanged(_ patientText: String) -> Bool {
        let t = Self.withoutFillers(patientText, fillers: config.shortAnswers.fillers)
        let compact = Self.normalized(t)
        guard soundsNegative(t) || config.followUpCall.unchangedAnswers.contains(where: { compact.contains(Self.normalized($0)) })
        else { return false }
        if ["근데", "그런데", "는데", "지만", "한데"].contains(where: { compact.contains($0) }) { return false }
        // "똑같지 않아요", "그대로가 아니에요": 달라졌다는 뜻이라 모델이 본다 (띄어쓰기 없이 비교)
        if ["지않", "진않", "가아니", "이아니", "게아니"].contains(where: { compact.contains($0) }) { return false }
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

    func isShortYes(_ patientText: String) -> Bool {
        config.shortAnswers.yes.contains(Self.normalized(patientText))
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
        KeywordMatcher.clauses(text.replacingOccurrences(of: #"고\s+"#, with: "고,", options: .regularExpression))
    }

    static func hasContrast(_ text: String) -> Bool {
        text.range(of: #"[가-힣]데요?(?=[\s,.?!]|$)|지만|그래도|대신"#, options: .regularExpression) != nil
    }

    /// 되묻는 말 앞뒤에 붙어도 되는 말 ("죄송한데 다시 말씀해 주시겠어요?")
    static let repeatCourtesy = ["죄송한데", "죄송하지만", "죄송해요", "저기요", "잠깐만요", "네", "예", "좀"]

    /// 띄어쓰기·문장 부호를 뺀 말 (낱말 비교용)
    static func normalized(_ s: String) -> String { String(s.filter { !$0.isWhitespace && !$0.isPunctuation }) }
}
