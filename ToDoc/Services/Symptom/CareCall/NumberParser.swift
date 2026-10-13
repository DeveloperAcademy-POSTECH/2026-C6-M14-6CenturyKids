//
//  NumberParser.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

/// 환자 발화의 숫자를 읽는다.
/// - numbers: 0~10 숫자가 있는지 (짧은 '없음'·'모름' 답, 기타 증상 이름 판단에서 숫자가 섞인 답을 걸러 낸다)
/// - count·minutes: 횟수·기간 답에서 분명한 값 하나 (증상 기록의 occurrenceCount·durationMinutes)
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

    // MARK: - 횟수·기간 (증상 기록 저장용)

    /// "한두", "두세"처럼 두 수를 붙여 말한 어림수. 하나로 정할 수 없어 읽지 않는다
    private static let approximate = ["한두", "두세", "서너", "너덧", "네다섯", "대여섯", "예닐곱", "일여덟", "엳아홉"]
    private static let native: [String: Int] = [
        "한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9,
    ]
    private static let sino: [Character: Int] = ["일": 1, "이": 2, "삼": 3, "사": 4, "오": 5, "육": 6, "칠": 7, "팔": 8, "구": 9]

    /// 횟수 답에서 분명한 횟수 하나 ("하루 세 번" → 3, "한 3번?" → 3, "열두 번" → 12).
    /// 어림수("두세 번"), 범위("2~3번"), 서로 다른 횟수가 둘 이상이면 nil. 1~100만 (SymptomEntry 규칙)
    static func count(in raw: String) -> Int? {
        guard !isAmbiguous(raw) else { return nil }
        let values = Set(raw.matches(of: /(\d+|[가-힣]{1,3})\s?(?:번|회|차례)(?!째)/).compactMap { value(of: String($0.1), allowsSino: false) })
        guard values.count == 1, let n = values.first, (1...100).contains(n) else { return nil }
        return n
    }

    /// 기간 답에서 분명한 길이 하나를 분으로 ("30분쯤" → 30, "한 시간 반" → 90, "1시간 30분" → 90).
    /// 어림수·범위, 길이가 둘 이상이면 nil. 10~1440분만 (SymptomEntry 규칙). "삼분의 일" 같은 분수는 기간이 아니다
    static func minutes(in raw: String) -> Int? {
        guard !isAmbiguous(raw) else { return nil }
        let hours = raw.matches(of: /(\d+|[가-힣]{1,3})\s?시간(\s?반)?/).compactMap { m in
            value(of: String(m.1), allowsSino: false).map { $0 * 60 + (m.2 == nil ? 0 : 30) }
        }
        let mins = raw.matches(of: /(\d+|[가-힣]{1,4})\s?분(?!의)/).compactMap { value(of: String($0.1), allowsNative: false) }
        guard hours.count <= 1, mins.count <= 1, !(hours.isEmpty && mins.isEmpty) else { return nil }
        let total = (hours.first ?? 0) + (mins.first ?? 0)
        return (10...1440).contains(total) ? total : nil
    }

    private static func isAmbiguous(_ raw: String) -> Bool {
        approximate.contains(where: raw.contains) || raw.contains(/\d+\s*[~\-]\s*\d+/)
    }

    /// 숫자, 또는 수를 나타내는 우리말("세", "열두")·한자어("삼십")를 읽는다. 앞에 다른 말이 붙어 있으면("하루세") 뒤쪽만 본다.
    /// 횟수·시간은 우리말만("이번 주"의 "이", "이 시간"을 수로 읽지 않게), 분은 한자어만("두 분"은 사람 수)
    private static func value(of token: String, allowsNative: Bool = true, allowsSino: Bool = true) -> Int? {
        if let n = Int(token) { return n }
        for start in token.indices {
            let tail = String(token[start...])
            if allowsNative, let n = nativeValue(tail) { return n }
            if allowsSino, let n = sinoValue(tail) { return n }
        }
        return nil
    }

    /// 우리말 수: 한~아홉, 열·열한~열아홉, 스무·스물
    private static func nativeValue(_ s: String) -> Int? {
        if let n = native[s] { return n }
        for (prefix, tens) in [("열", 10), ("스무", 20), ("스물", 20)] where s.hasPrefix(prefix) {
            let rest = String(s.dropFirst(prefix.count))
            if rest.isEmpty { return tens }
            if let n = native[rest] { return tens + n }
        }
        return nil
    }

    /// 한자어 수: 일~구, 십, 이십·삼십…, 십오·이십오… (분을 말할 때)
    private static func sinoValue(_ s: String) -> Int? {
        guard !s.isEmpty, s.allSatisfy({ sino[$0] != nil || $0 == "십" }) else { return nil }
        guard let ten = s.firstIndex(of: "십") else { return s.count == 1 ? sino[s.first!] : nil }
        let before = s[..<ten], after = s[s.index(after: ten)...]
        guard before.count <= 1, after.count <= 1 else { return nil }
        return (before.first.flatMap { sino[$0] } ?? 1) * 10 + (after.first.flatMap { sino[$0] } ?? 0)
    }
}
