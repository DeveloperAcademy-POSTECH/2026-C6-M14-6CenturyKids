//
//  KeywordMatcher.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// 부정·문맥을 보는 키워드 판별. 응급 키워드(emergency_rules.json, 모델 emergencySignal과 OR)와 증상 표현(side_effects.json symptomHints)에 쓴다. 둘 다 임시값.
/// 키워드 바로 뒤가 부정("숨이 차지 않아요", "고열은 없어요")이면 그 키워드는 응급으로 보지 않는다.
/// 애매하면 응급으로 본다: 부정이 키워드에 바로 붙지 않았거나("숨이 차서 잘 수가 없어요"), 같은 절에 부정이 또 있으면("숨이 차지 않은 건 아니에요") 응급.
struct KeywordMatcher: Sendable {
    let keywords: [String]
    /// 키워드 바로 앞의 "안"("안 아파요")도 부정으로 볼지. 응급 키워드는 놓치지 않도록 false
    var prefixNegation = false
    /// 띄어 쓴 키워드의 낱말 사이에 끼어도 되는 낱말 수 ("피를 토" ← "피를 한 바가지 토했어요"). 응급 키워드만 2
    var maxGapWords = 0

    func matches(_ text: String) -> String? {
        for clause in Self.clauses(text) {
            for keyword in keywords {
                var from = clause.startIndex
                while let range = clause.range(of: Self.pattern(keyword, maxGapWords: maxGapWords), options: .regularExpression, range: from..<clause.endIndex) {
                    let rest = clause[range.upperBound...].replacingOccurrences(of: " ", with: "")
                    let before = clause[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    // 증상 표현 모드: 앞의 "안"("안 아파요")과 바로 뒤의 "안"("열이 안 나요")도 부정
                    let negatedBefore = prefixNegation && (before == "안" || before.hasSuffix(" 안") || rest.hasPrefix("안"))
                    // 증상 표현 모드: "뻐근한 데는 없어요", "쑤시는 데 없어요"도 부정 ("아픈데 없어지질 않아요", "없진 않아요"는 아니다)
                    let negatedPlace = prefixNegation
                        && rest.range(of: #"^(?:하|한|는|은)?(?:데|곳|부분|부위)(?:는|도|은|가)?(?:없(?!어지|어져|진|지는|지않)|않|아니)"#,
                                      options: .regularExpression) != nil
                    if !Self.negated(rest), !negatedBefore, !negatedPlace { return keyword }
                    from = range.upperBound
                }
            }
        }
        return nil
    }

    /// 키워드 안의 공백 자리만 띄어쓰기를 무시한다 ("숨이 차" = "숨이차"). 공백 없는 키워드는 낱말 경계를 넘지 않는다
    /// ("그리고 열이"의 "고 열"은 "고열"이 아님). maxGapWords만큼 다른 낱말이 끼어도 된다
    static func pattern(_ keyword: String, maxGapWords: Int = 0) -> String {
        let gap = maxGapWords > 0 ? "(?:\\s+\\S+){0,\(maxGapWords)}\\s*" : "\\s*"
        return keyword.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: gap)
    }

    /// 쉼표·마침표와 "~는데/~지만"에서 끊는다 ("숨이 차진 않은데 가슴이 아파요" → 두 절)
    static func clauses(_ text: String) -> [String] {
        text.replacingOccurrences(of: "(는데|은데|지만)", with: "$1,", options: .regularExpression)
            .split(whereSeparator: { ",.!?\n".contains($0) }).map(String.init)
    }

    /// 키워드 뒤 남은 절이 부정으로 시작하고, 그 뒤에 부정이 또 없으면 true
    static func negated(_ rest: String) -> Bool {
        // "피곤하진 않아"처럼 키워드 뒤 "하"가 붙은 부정도 같다
        let head = #"^하?(?:[은는이가도]|지|진|지도|지는|지를|는건|는게|은건|한건|한게|한거)?(?:않|없|아니|아냐)"#
        guard let r = rest.range(of: head, options: .regularExpression) else { return false }
        return rest[r.upperBound...].range(of: "(않|없|아니|아냐|못)", options: .regularExpression) == nil
    }
}
