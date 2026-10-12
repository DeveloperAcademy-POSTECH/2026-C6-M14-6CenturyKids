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
        /// 있음 다음, 강도 전에 묻는 질문 (횟수·시작 시점·섭취량). 답은 모델 없이 환자 말 그대로 기록
        let detailQuestion: String?
        /// 기록에 붙이는 이름 ("횟수", "시작", "섭취량")
        let detailLabel: String?
        /// false면 강도(0~10)를 묻지 않는다 (탈수·영양). 없으면 묻는다
        let asksSeverity: Bool?
        /// 다른 항목을 묻다가 이 항목의 횟수·강도·부위로 돌아갈 때 앞에 말하는 이름 ("입안이 헐거나 아픈 것")
        let spokenName: String
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
    let severityPrompt: String
    /// 두 번째 항목부터 쓰는 짧은 강도 질문 (같은 항목을 다시 물을 때는 긴 문구)
    let severityPromptShort: String
    let locationPrompt: String
    /// 유무 질문에 이 말로 시작하거나 끝나는 짧은 답은 모델 없이 '없음' (다른 증상·숫자·연결어가 없을 때만, 초안)
    let noPrefixes: [String]
    let noSuffixes: [String]
    /// 유무 질문에 이 말로 끝나는 답은 이유를 말한 것 → 있음 ("입이 아파서요" = 입이 아파서 많이 못 먹었다, 초안)
    let reasonSuffixes: [String]
    /// 유무·강도·부위 질문에 이 말이 든 답("잘 모르겠어요", "기억이 안 나요")은 다시 묻지 않고 '모름'으로 기록 (초안)
    let unknownAnswers: [String]
    /// 모델 없이 처리하는 짧은 답 (공백·문장부호를 뺀 뒤 완전히 같을 때만). 질문이 긍정형("~있으셨나요?")이라는 전제
    let shortAnswers: ShortAnswers
    /// 처음·그 밖에 답에 이 표현이 있는데 모델이 아무것도 기록하지 않으면 한 번 더 분석한다 (초안, 의료진 확인 필요)
    let symptomHints: [String]

    func returnPrefix(for effect: Effect) -> String {
        returnPrefix.replacingOccurrences(of: "{name}", with: effect.spokenName)
    }

    /// 통화 중 말할 고정 문구 (음성 미리 합성용). 응급 안내는 시스템 음성으로 읽으므로 넣지 않는다
    func spokenPhrases(rules: EmergencyRules) -> [String] {
        [aiVoiceNotice, openingQuestion, openingFollowUp, openingTransition.fine, openingTransition.noted, openingTransition.afterFollowUp]
            + effects.flatMap { [$0.ask, $0.detailQuestion].compactMap(\.self) } + effects.map(returnPrefix(for:))
            + acknowledgements + [repeatPrefix, otherDetail.question, otherDetail.recorded, severityPrompt, severityPromptShort,
                                  locationPrompt, otherQuestion, otherFollowUp, rules.closingMessage]
    }

    struct OpeningTransition: Decodable, Sendable {
        /// 문제없는 답 ("좋아요", "보통이에요")
        let fine: String
        /// 첫 답에서 증상을 말함 ("어제 토했어요")
        let noted: String
        /// 꼬리질문의 답 뒤
        let afterFollowUp: String
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
