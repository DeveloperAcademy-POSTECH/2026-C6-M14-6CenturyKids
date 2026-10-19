//
//  CareCallConfig.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// 케어콜 대본: 항목별 질문 문구와 공통 문구 (Resources/Config/side_effects.json).
/// 문구·키워드는 프로토타입 초안이며 의료진 확인이 필요하다.
struct CareCallConfig: Decodable, Sendable {
    struct Effect: Decodable, Sendable, Identifiable {
        /// AI 프롬프트가 쓰는 항목 ID ("nausea_vomiting" 등). 바꾸면 프롬프트도 바꾸고 다시 평가해야 한다
        let id: String
        let name: String
        let ask: String
        /// 환자가 이 증상을 직접 말했는지 보는 낱말 (다른 항목을 묻는 중 번복 판단용, 초안)
        let keywords: [String]
        let requiresLocation: Bool
        /// 있음 다음에 묻는 꼬리질문 (횟수·시작 시점·지속 시간·섭취량). 답은 모델 없이 환자 말 그대로 기록
        let details: [Detail]
        /// 다른 항목을 묻다가 이 항목의 횟수·부위로 돌아갈 때 앞에 말하는 이름 ("입안이 헐거나 아픈 것")
        let spokenName: String
        /// '없다'가 붙어도 이 증상이 있다는 말 ("입맛 없" = "입맛이 좀 없어요", 식사 증상 있음). 두 낱말이 한 절에서 차례로 가까이
        /// (사이 8자 이내) 나오면 맞는다. 모델이 '없음'이라 해도 '있음'으로 본다. 약 이야기 절("약을 잘 못 먹어요")은 보지 않는다 (초안)
        let presentPhrases: [String]?

        struct Detail: Decodable, Sendable {
            /// 기록에 붙이는 이름 ("횟수", "구토 횟수"). 한 항목 안에서 겹치지 않는다
            let label: String
            let question: String
            /// 저장할 때 답에서 읽을 숫자 (count → occurrenceCount, minutes → durationMinutes). 없으면 답만 남긴다
            let number: Number?
            /// 환자가 이 말을 했을 때만 묻는다 (구토 → 횟수, 메스꺼움 → 시작). 없으면 늘 묻는다
            let keywords: [String]?

            enum Number: String, Decodable, Sendable {
                case count, minutes
            }
        }

        /// 이 항목에서 물을 꼬리질문. 낱말이 있는 질문은 환자가 그 말을 했을 때만 묻고("토했어요" → 횟수만),
        /// 어느 쪽인지 말하지 않았으면("네") 전부 묻는다. "토하진 않았어요"처럼 부정한 말은 보지 않는다
        func details(heard quotes: [String]) -> [Detail] {
            let heard = details.filter { detail in
                guard let keywords = detail.keywords else { return true }
                let matcher = KeywordMatcher(keywords: keywords, prefixNegation: true)
                return quotes.contains { matcher.matches($0) != nil }
            }
            return heard.contains { $0.keywords != nil } ? heard : details
        }
    }

    let version: String
    let effects: [Effect]
    /// 음성 통화 첫마디. 상대가 AI 음성임을 알린다 (Supertonic 라이선스 의무, 초안)
    let aiVoiceNotice: String
    let openingQuestion: String
    let otherQuestion: String
    /// 첫 질문 꼬리질문: 답에 증상 표현(symptomHints)이나 컨디션이 나쁘다는 말(openingConcerns)이 있고 목록 증상이 기록되지 않았으면 한 번
    let openingFollowUp: String
    /// 첫 질문 다음, 증상 질문 앞에 붙이는 말
    let openingTransition: OpeningTransition
    /// 같은 날 다시 거는 케어콜 (오늘 기록이 이미 있을 때)
    let followUpCall: FollowUpCall
    /// 이 말이 든 첫 답(증상 표현·연결어 없을 때)은 모델 없이 넘어간다 ("좋아요", "보통이에요")
    let openingFine: [String]
    let openingConcerns: [String]
    /// '그 밖에' 질문에 "네"만 답했을 때 되묻는 말
    let otherFollowUp: String
    /// 모델이 분석하는 동안 먼저 말하는 맞장구 (차례로 돌려 씀). 모델 없이 처리하는 답과 첫 질문 답에는 쓰지 않는다
    let acknowledgements: [String]
    /// 오류·불분명으로 같은 질문을 다시 할 때 앞에 붙이는 말
    let repeatPrefix: String
    /// 다른 항목으로 돌아가 물을 때 앞에 붙이는 말. {name} = spokenName
    let returnPrefix: String
    /// '그 밖에'에서 기타 증상을 말하면 한 번 더 묻고(question) 답을 그대로 기록(label)한 뒤 마무리 인사 앞에 붙이는 말(recorded)
    let otherDetail: OtherDetail
    let locationPrompt: String
    /// 유무 질문에 이 말로 시작하거나 끝나는 짧은 답은 모델 없이 '없음' (다른 증상·숫자·연결어가 없을 때만, 초안)
    let noPrefixes: [String]
    let noSuffixes: [String]
    /// 유무 질문에 이 말로 끝나는 답은 이유를 말한 것 → 있음 ("입이 아파서요" = 입이 아파서 많이 못 먹었다, 초안)
    let reasonSuffixes: [String]
    /// 유무·부위 질문에 이 말이 든 답("잘 모르겠어요", "기억이 안 나요")은 다시 묻지 않고 '모름'으로 기록 (초안)
    let unknownAnswers: [String]
    /// 유무 질문에 있다고도 없다고도 하지 않은 답("그냥 좀 그래요", "글쎄요")의 낱말. 다시 묻지 않고 '모름' + 검토 필요로,
    /// 환자 말은 그대로 남긴다 (모델은 이런 답을 대부분 '있음'으로 기록했다, 2026-10-14 평가. 초안).
    /// 다시 거는 통화의 첫 질문에 이런 답이면 '달라진 점'을 '모름'으로 남긴다
    let vagueAnswers: [String]
    /// '그 밖에' 질문에 "모르겠어요"·"그냥 그래요"라고 하면 이 이름의 기타 항목에 '모름'으로 원문을 남긴다
    let otherUnclearName: String
    /// 모델 없이 처리하는 짧은 답 (공백·문장부호를 뺀 뒤 완전히 같을 때만). 질문이 긍정형("~있으셨나요?")이라는 전제
    let shortAnswers: ShortAnswers
    /// 처음·그 밖에 답에 이 표현이 있는데 모델이 아무것도 기록하지 않으면 한 번 더 분석한다 (초안, 의료진 확인 필요)
    let symptomHints: [String]

    func returnPrefix(for effect: Effect) -> String {
        returnPrefix.replacingOccurrences(of: "{name}", with: effect.spokenName)
    }

    /// 통화 중 말할 고정 문구 (음성 미리 합성용). 응급 안내는 시스템 음성으로 읽으므로 넣지 않는다
    func spokenPhrases(rules: EmergencyRules) -> [String] {
        [aiVoiceNotice, openingQuestion, openingFollowUp, openingTransition.fine, openingTransition.noted, openingTransition.afterFollowUp,
         followUpCall.question, followUpCall.noted, followUpCall.resume, followUpCall.notedAndResume, followUpCall.unchanged]
            + effects.flatMap { [$0.ask] + $0.details.map(\.question) } + effects.map(returnPrefix(for:))
            + acknowledgements + [repeatPrefix, otherDetail.question, otherDetail.recorded, locationPrompt,
                                  otherQuestion, otherFollowUp, rules.closingMessage]
    }

    struct OpeningTransition: Decodable, Sendable {
        /// 문제없는 답 ("좋아요", "보통이에요")
        let fine: String
        /// 첫 답에서 증상을 말함 ("어제 토했어요")
        let noted: String
        /// 꼬리질문의 답 뒤
        let afterFollowUp: String
    }

    struct FollowUpCall: Decodable, Sendable {
        /// 첫 질문 ("다시 연결됐어요. 아까 통화 뒤로 달라졌거나 새로 불편해진 점이 있으세요?")
        let question: String
        /// 달라진 게 없다는 답의 낱말 ("똑같아요", "그대로예요"). "없어요·괜찮아요"는 없음 표현으로 본다
        let unchangedAnswers: [String]
        /// 첫 답에서 증상을 말함 → 그 증상을 묻기 전에
        let noted: String
        /// 지난 통화가 끊겨 못 물은 증상을 이어서 물을 때
        let resume: String
        let notedAndResume: String
        /// 달라진 게 없음 → 마무리 인사 앞에
        let unchanged: String
        /// 첫 질문에 "글쎄요"처럼 답하면 이 이름의 기타 항목에 '모름'으로 남긴다
        let unclearName: String
        /// 증상이 그쳤다는 낱말 ("멈췄어요"). 첫 답에서 모델이 그 증상을 못 잡으면 '없음'으로 남긴다.
        /// "없어졌·사라졌"은 넣지 않는다 ("입맛이 없어졌어요"는 식사 증상이 생긴 것)
        let stoppedAnswers: [String]
    }

    struct OtherDetail: Decodable, Sendable {
        let question: String
        let label: String
        let recorded: String
    }

    struct ShortAnswers: Decodable, Sendable {
        let yes: [String]
        let no: [String]
        /// 답 앞에 붙는 말("어", "음", "응"). 띄어 쓴 낱말 단위로만 뗀다 ("아프지 않아"의 "아"는 떼지 않음)
        let fillers: [String]
    }
}

/// 응급 규칙 (Resources/Config/emergency_rules.json). 임시값이며 의료진 확인 전까지 키워드와 문구는 확정이 아니다.
struct EmergencyRules: Decodable, Sendable {
    let version: String
    let keywords: [String]
    /// 이 온도(섭씨) 이상을 말하면 응급. "열이 조금 나요", "미열"은 응급 아님
    let feverCelsius: Double
    /// 응급일 때 말하고 통화를 끝내는 고정 안내
    let message: String
    /// 정상 종료 때 마무리 인사
    let closingMessage: String

    /// "38도", "38.5도", "열이 39", "체온 40" 처럼 기준 이상 온도를 말했는지. 부정("38도는 안 넘었어요")은 보지 않는다 (애매하면 응급)
    func mentionsFever(_ text: String) -> Bool {
        text.matches(of: /(?:열이|체온이?)\s*(\d{2}(?:\.\d+)?)|(\d{2}(?:\.\d+)?)\s*도/).contains { m in
            guard let s = m.1 ?? m.2, let t = Double(s) else { return false }
            return t >= feverCelsius && t <= 45
        }
    }
}

extension Bundle {
    func decodeJSON<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        guard let url = url(forResource: name, withExtension: "json") else {
            throw CareCallConfigError.missing("\(name).json")
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
