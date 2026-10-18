//
//  Ledger.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// 항목별 누적 기록. 모델 출력은 여기서 검증한 뒤에만 반영한다.
struct Ledger: Sendable {
    struct Entry: Equatable, Sendable {
        let key: String
        let effectId: String
        var otherName: String?
        var presence: MentionPresence?
        var locations: [String] = []
        /// 꼬리질문(횟수·시작 시점·지속 시간·섭취량) 답. 물은 순서대로
        var details: [Detail] = []
        var quotes: [String] = []
        var needsReview = false
        /// 같은 항목에서 이미 물은 단계. 다시 물으면 꼬리질문으로 센다.
        var askedSteps: Set<CareCallStep> = []
        var followUps = 0
        /// 꼬리질문 한도 초과로 더 묻지 않음
        var closed = false
        /// 환자가 "모르겠어요"라고 답한 단계. 다시 묻지 않고 '모름'으로 기록한다
        var unknownSteps: Set<CareCallStep> = []
        /// 모르겠다·애매하다고 한 답 원문 ("잘 모르겠어요", "그냥 좀 그래요"). 부위 질문의 답은 "부위: …"
        var unsureAnswers: [String] = []
    }

    /// 꼬리질문 답 (환자 말 그대로)과 그 질문 이름
    struct Detail: Equatable, Sendable {
        let label: String
        let text: String
    }

    static let maxFollowUps = 2

    private(set) var entries: [String: Entry] = [:]
    /// 첫 질문(오늘 컨디션) 답 원문
    private(set) var conditionText: String?
    /// 처음 기록된 순서 (기타 부작용 질문 순서용)
    private(set) var order: [String] = []

    static func key(effectId: String, otherName: String?) -> String {
        effectId == "other" ? "other:\(otherName ?? "")" : effectId
    }

    subscript(key: String) -> Entry? { entries[key] }

    /// 모델이 낸 언급을 환자 발화로 검증해 반영한다.
    /// - 부위: 환자 발화에 있는 말만
    /// - 있음↔없음 번복: 최신 값으로 바꾸고 검토 필요
    /// - mayChangeRecorded: false면 이미 기록된 있음/없음은 바꾸지 않고 빈 값만 채운다.
    mutating func apply(_ mention: Mention, patientText: String, knownEffectIds: Set<String>, mayChangeRecorded: Bool = true) {
        guard Self.grounded(mention.quote, in: patientText) else { return }
        var effectId = mention.effectId
        var otherName = mention.otherName?.trimmingCharacters(in: .whitespaces)
        if effectId != "other", !knownEffectIds.contains(effectId) {
            // 목록 ID를 변형한 것("stomatitis_detail" 등)은 버린다. 그 밖의 목록 밖 ID(모델이 만든 "headache" 등)는 기타로 받는다
            if knownEffectIds.contains(where: { effectId.hasPrefix($0) }) { return }
            effectId = "other"
        }
        // 이름은 기타 증상에만 둔다. 모델이 목록 증상에도 빈 이름("")을 붙여 내용이 ": 세 번이요"로 저장됐다 (2026-10-17 실기기)
        if effectId != "other" { otherName = nil }
        // 기타는 이름이 있어야 받는다 (이름 정리는 InterviewEngine.normalizedOthers)
        if effectId == "other", (otherName ?? "").isEmpty { return }

        let key = Self.key(effectId: effectId, otherName: otherName)
        if !mayChangeRecorded, let recorded = entries[key]?.presence,
           recorded != .unclear, mention.presence != recorded { return }
        var entry = entries[key] ?? Entry(key: key, effectId: effectId, otherName: otherName)
        if entries[key] == nil { order.append(key) }

        switch (entry.presence, mention.presence) {
        case (.present, .absent), (.absent, .present):
            entry.needsReview = true
            entry.presence = mention.presence
            entry.closed = false
            // 번복 전 부위는 버린다 (다시 물어 채움)
            entry.locations = []
        case (.some(.present), .unclear), (.some(.absent), .unclear):
            break // 이미 확인된 값을 불명확으로 낮추지 않는다
        default:
            entry.presence = mention.presence
        }

        for location in mention.locations where Self.mentioned(location, in: patientText) {
            if !entry.locations.contains(location) { entry.locations.append(location) }
        }
        entry.quotes.append(patientText)
        entries[key] = entry
    }

    /// "모르겠어요"·"그냥 좀 그래요" 같은 답: 그 단계를 '모름'으로 기록하고 다시 묻지 않는다 (2026-10-08 사용자 결정: 되묻기 대상이 아니라 기록할 답).
    /// 유무를 모르면 있음/없음 대신 unclear로 둔다. 의료진이 보도록 검토 필요 표시와 환자 말 원문을 남긴다
    mutating func markUnknown(_ key: String, step: CareCallStep, quote: String) {
        guard var entry = entries[key] else { return }
        entry.unknownSteps.insert(step)
        if step == .presence { entry.presence = .unclear }
        entry.needsReview = true
        entry.quotes.append(quote)
        let said = quote.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if !said.isEmpty { entry.unsureAnswers.append(step == .location ? "부위: " + said : said) }
        entries[key] = entry
    }

    mutating func setConditionText(_ text: String) {
        conditionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func addDetail(_ text: String, label: String, for key: String) {
        entries[key]?.details.append(Detail(label: label, text: text))
    }

    /// 기록 값(있음/없음·부위)이 같은지. 근거 문장(quotes)과 질문 횟수는 보지 않는다
    func sameRecords(as other: Ledger) -> Bool {
        order == other.order && entries.allSatisfy { key, e in
            guard let o = other.entries[key] else { return false }
            return e.presence == o.presence && e.locations == o.locations
        }
    }

    mutating func markNeedsReview(_ key: String) {
        entries[key]?.needsReview = true
    }

    /// 단계를 묻기 전에 호출. 꼬리질문 한도를 넘으면 false (항목을 닫고 검토 필요 표시).
    mutating func markAsked(_ key: String, step: CareCallStep) -> Bool {
        var entry = entries[key] ?? Entry(key: key, effectId: key, otherName: nil)
        if entries[key] == nil { order.append(key) }
        // 꼬리질문이 둘인 항목(구토 횟수·메스꺼움 시작)은 다음 질문이라 되묻기로 세지 않는다
        if entry.askedSteps.contains(step), step != .detail {
            if entry.followUps >= Self.maxFollowUps {
                entry.needsReview = true
                entry.closed = true
                entries[key] = entry
                return false
            }
            entry.followUps += 1
        }
        entry.askedSteps.insert(step)
        entries[key] = entry
        return true
    }

    func summaryText(names: [String: String]) -> String {
        let lines = order.compactMap { key -> String? in
            guard let e = entries[key], let presence = e.presence else { return nil }
            let name = e.effectId == "other" ? (e.otherName ?? "기타") : (names[e.effectId] ?? e.effectId)
            var parts = ["\(name): \(e.unknownSteps.contains(.presence) ? "모름" : presence.rawValue)"]
            parts += e.details.map { "\($0.label) ‘\($0.text)’" }
            if !e.locations.isEmpty { parts.append("부위 \(e.locations.joined(separator: ", "))") }
            if e.unknownSteps.contains(.location) { parts.append("부위 모름") }
            if e.needsReview { parts.append("검토 필요") }
            return parts.joined(separator: ", ")
        }
        return lines.isEmpty ? "기록 없음" : lines.joined(separator: "\n")
    }

    /// 모델이 단 근거(quote)가 환자 발화에서 왔는지. 낱말 절반 이상이 발화에 있어야 인정.
    /// 비어 있으면 인정하지 않는다. 다른 문장(질문 문구, 기록 요약)을 근거로 단 언급을 막는다.
    static func grounded(_ quote: String, in patientText: String) -> Bool {
        let words = quote.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        guard !words.isEmpty else { return false } // 빈 근거: 모델이 환자가 말하지 않은 항목을 '없음'으로 채운 경우 (프로토타입 평가에서 확인)
        let hits = words.filter { patientText.contains($0) }.count
        return hits * 2 >= words.count
    }

    private static func mentioned(_ location: String, in text: String) -> Bool {
        if text.contains(location) { return true }
        // 여러 낱말로 된 부위("양쪽 손")는 첫 낱말이 두 글자 이상이면 그 낱말만 있어도 인정
        guard let first = location.split(separator: " ").first, first.count >= 2 else { return false }
        return text.contains(first)
    }
}
