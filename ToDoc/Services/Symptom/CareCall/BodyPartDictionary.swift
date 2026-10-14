//
//  BodyPartDictionary.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif
import Foundation

/// 환자가 말한 부위 낱말("손", "허벅지 안쪽", "양손")을 BodyPart·BodySide로 바꾸는 사전 (Resources/Config/body_parts.json, 초안).
/// 증상 기록을 저장할 때 쓰고, 원래 낱말은 rawLocationText로 따로 남긴다.
struct BodyPartDictionary: Decodable, Sendable {
    /// BodyPart 원시값 → 그 부위를 가리키는 낱말
    let parts: [String: [String]]
    /// BodySide 원시값 → 낱말 앞에 붙는 말 ("왼", "양")
    let sides: [String: [String]]

    /// 낱말에 든 사전 낱말 중 가장 긴 것으로 고른다 ("손목"은 목이 아니라 팔·손). 사전에 없으면 nil
    func bodyPart(for word: String) -> BodyPart? {
        let match = parts.flatMap { part, words in words.map { (part, $0) } }
            .filter { word.contains($0.1) }
            .max { ($0.1.count, $0.0) < ($1.1.count, $1.0) }
        return match.flatMap { BodyPart(rawValue: $0.0) }
    }

    /// 낱말 앞에 좌우를 말했을 때만 ("왼손", "양쪽 발"). 없으면 nil
    func bodySide(for word: String) -> BodySide? {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        return sides.first { _, prefixes in prefixes.contains { trimmed.hasPrefix($0) } }
            .flatMap { BodySide(rawValue: $0.key) }
    }
}
