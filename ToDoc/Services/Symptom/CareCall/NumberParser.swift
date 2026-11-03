//
//  NumberParser.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

/// 환자 발화의 숫자를 읽는다.
/// - numbers: 0~10 숫자·"N점" (강도 점수를 묻던 때의 판단. 숫자가 섞인 답을 걸러 낼 때는 hasNumber)
/// - hasNumber: 답에 숫자가 있는지. 말로 한 횟수·시간("두 번", "한 시간", "두세 번")까지 본다
/// - count: 횟수 답에서 분명한 값 하나 (증상 기록의 occurrenceCount)
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

    // MARK: - 횟수 (증상 기록 저장용)

    /// "한두", "두세"처럼 두 수를 붙여 말한 어림수. 하나로 정할 수 없어 읽지 않는다
    private static let approximate = ["한두", "두세", "서너", "너덧", "네다섯", "대여섯", "예닐곱", "일여덟", "엳아홉",
                                      "이삼", "삼사", "사오", "오륙", "육칠", "칠팔", "팔구"] // 한자어 어림수 ("이삼십 분")
    private static let native: [String: Int] = [
        "한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9,
    ]

    /// 답에 숫자가 있는지: 숫자 글자, "N점", 말로 한 횟수·시간 ("두 번", "열두 번", "한 시간", "삼십 분", "두세 번").
    /// 숫자가 섞인 답은 짧은 답 규칙('없음'·'모름'·애매한 답)으로 처리하지 않고 모델이 보게 할 때 쓴다 (넓게 잡아도 모델이 볼 뿐이다)
    static func hasNumber(_ raw: String) -> Bool {
        raw.contains(/\d/) || !numbers(in: raw).isEmpty
            || raw.contains(/(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|스무|스물|서른|마흔|쉰|예순|일흔|여든|아흔)\s?(번|회|차례|시간|달)/)
            || raw.contains(/(일|이|삼|사|오|육|칠|팔|구|십|백)\s?(분|주|개월|회)/)
            // 한자어 수 + 번은 십·백이 들어 있을 때만 ("이십 번"). "이번", "사번"은 숫자가 아니다
            || raw.contains(/[일이삼사오육칠팔구]?[십백][일이삼사오육칠팔구]?\s?(번|차례)/)
    }

    /// 횟수 답에서 분명한 횟수 하나 ("하루 세 번" → 3, "한 3번?" → 3, "열두 번" → 12).
    /// 어림수("두세 번"), 범위("2~3번"), 서로 다른 횟수가 둘 이상이면 nil. 1~100만 (SymptomEntry 규칙)
    static func count(in raw: String) -> Int? {
        guard !isAmbiguous(raw) else { return nil }
        let values = Set(raw.matches(of: /(\d+|[가-힣]{1,3})\s?(?:번|회|차례)(?!째)/).compactMap { value(of: String($0.1)) })
        guard values.count == 1, let n = values.first, (1...100).contains(n) else { return nil }
        return n
    }

    /// 어림수·범위, 그보다 많거나 적다는 말 (정확한 값이 아니다)
    private static func isAmbiguous(_ raw: String) -> Bool {
        approximate.contains(where: raw.contains) || raw.contains(/\d+\s*[~\-]\s*\d+/) || raw.contains(overOrUnder)
    }

    /// "열 번 넘게", "10번은 넘었어요", "열 번 훨씬 넘어요", "한 시간 반 이상", "열 번 남짓", "열 번 가까이", "다섯 번 이하",
    /// "삼십 분 이내", "한 시간 안 돼요", "적어도 세 번". 수 바로 뒤 단위만 본다("저번", "기분", "부분"은 단위가 아니다).
    /// 단위 뒤 조사(은·도·이)와 정도 말(좀·훨씬·정도)은 건너뛴다. "넘어졌어요"·"넘겼어요"·"이상했어요"는 수량 말이 아니다
    private static let overOrUnder = /[\d한두세네섯곱덟홉열물무백십일이삼사오육칠팔구]\s?(시간\s?반|번|회|차례|시간|분)(은|는|도|이|가)?\s?(좀|조금|약간|훨씬|더|정도)?\s?(넘(게|었|어(?![지졌져질])|는|을|지|고|음)|이상(?![해하한했할함히])|남짓|가까이|이하|미만|안팎|이내|안\s?[되돼됐]|못\s?[되돼됐])|적어도|최소/

    /// 숫자, 또는 수를 나타내는 우리말("세", "열두")을 읽는다. 앞에 다른 말이 붙어 있으면("하루세") 뒤쪽만 본다.
    /// 한자어는 읽지 않는다 ("이번 주"의 "이"를 수로 읽지 않게)
    private static func value(of token: String) -> Int? {
        if let n = Int(token) { return n }
        return token.indices.lazy.compactMap { nativeValue(String(token[$0...])) }.first
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
}
