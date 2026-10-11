//
//  SeverityParser.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

/// 환자 발화에서 0~10 점수를 찾는다. 숫자, 또는 "점"이 붙은 우리말·한자어 수만 인정.
/// "많이 아파요" 같은 표현은 숫자가 아니므로 결과 없음.
enum SeverityParser {
    private static let words: [String: Int] = [
        "영": 0, "빵": 0,
        "일": 1, "이": 2, "삼": 3, "사": 4, "오": 5, "육": 6, "칠": 7, "팔": 8, "구": 9, "십": 10,
        "한": 1, "하나": 1, "두": 2, "둘": 2, "세": 3, "셋": 3, "네": 4, "넷": 4, "다섯": 5,
        "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10,
    ]

    /// 아래 정수 읽기에서는 소수("7.5", "0.250")를 지운다. 소수 점수는 scores(in:)가 따로 읽는다
    private static func withoutDecimals(_ text: String) -> String {
        text.replacing(/\d+[.,]\d+/, with: " ")
    }

    /// "점"이 붙은 수만 (예: "3점", "삼 점"). 강도를 묻지 않은 답에서 숫자를 강도로 쓸 때 사용 ("3일째" 같은 수 제외)
    static func pointNumbers(in raw: String) -> Set<Int> {
        let text = withoutDecimals(raw)
        var found = Set<Int>()
        for match in text.matches(of: /(\d+)\s?점/) {
            if let n = Int(match.1), (0...10).contains(n) { found.insert(n) }
        }
        let spoken = /(영|빵|일|이|삼|사|오|육|칠|팔|구|십|하나|한|두|둘|세|셋|네|넷|다섯|여섯|일곱|여덟|아홉|열)\s?점/
        for match in text.matches(of: spoken) {
            if let n = words[String(match.1)] { found.insert(n) }
        }
        return found
    }

    /// 강도로 인정하는 점수: 정수(numbers) + 숫자로 말한 소수 (예: "3.5 점", "6.25"). 0~10만.
    /// 소수는 소수점 아래 두 자리까지만, 숫자·점이 이어진 덩어리("6.6.6.6", "0.250")는 음성 인식 오류로 보고 버린다
    static func scores(in raw: String) -> Set<Double> {
        var found = Set(numbers(in: raw).map(Double.init))
        for match in raw.matches(of: /\d{1,2}\.\d{1,2}/) {
            let before = raw[..<match.range.lowerBound].last, after = raw[match.range.upperBound...]
            if let b = before, b.isNumber || b == "." { continue }
            if after.first?.isNumber == true || (after.first == "." && after.dropFirst().first?.isNumber == true) { continue }
            if let v = Double(match.output), (0...10).contains(v) { found.insert(v) }
        }
        return found
    }

    /// 기록·읽어 주기용 ("6", "3.5")
    static func text(_ score: Double) -> String {
        score == score.rounded() ? String(Int(score)) : String(score)
    }

    static func numbers(in raw: String) -> Set<Int> {
        let text = withoutDecimals(raw)
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
