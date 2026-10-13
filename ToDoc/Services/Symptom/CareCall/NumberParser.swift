//
//  NumberParser.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

/// 환자 발화에 0~10 숫자가 있는지 찾는다. 숫자, 또는 "점"이 붙은 우리말·한자어 수만 인정.
/// 짧은 '없음' 답·'모름' 답·기타 증상 이름을 판단할 때 숫자가 섞인 답("아니요, 3번이요")을 걸러 낸다.
enum NumberParser {
    private static let words: [String: Int] = [
        "영": 0, "빵": 0,
        "일": 1, "이": 2, "삼": 3, "사": 4, "오": 5, "육": 6, "칠": 7, "팔": 8, "구": 9, "십": 10,
        "한": 1, "하나": 1, "두": 2, "둘": 2, "세": 3, "셋": 3, "네": 4, "넷": 4, "다섯": 5,
        "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10,
    ]

    static func numbers(in raw: String) -> Set<Int> {
        // 소수("7.5")는 지우고 정수만 읽는다
        let text = raw.replacing(/\d+[.,]\d+/, with: " ")
        var found = Set<Int>()
        // 숫자: 연속된 숫자 전체를 읽고 0~10만 (예: "6점", "한 6", "10". "39도"는 제외)
        for match in text.matches(of: /\d+/) {
            if let n = Int(match.output), (0...10).contains(n) { found.insert(n) }
        }
        // 말: 바로 뒤에 "점"이 와야 함 (조사 "이", "네" 오인 방지)
        let spoken = /(영|빵|일|이|삼|사|오|육|칠|팔|구|십|하나|한|두|둘|세|셋|네|넷|다섯|여섯|일곱|여덟|아홉|열)\s?점/
        for match in text.matches(of: spoken) {
            if let n = words[String(match.1)] { found.insert(n) }
        }
        return found
    }
}
