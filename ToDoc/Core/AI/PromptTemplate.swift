//
//  PromptTemplate.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//

import Foundation

/// Resources/Prompts/prompt-*.json. 프롬프트는 코드에 두지 않는다.
struct PromptTemplate: Decodable, Sendable {
    struct Example: Decodable, Sendable {
        let input: String
        let output: String
    }

    /// 0이면 그리디 (같은 입력 → 같은 출력)
    let temperature: Double?
    let instructions: String
    let slotTemplate: String
    let fewShot: [Example]

    /// few-shot 예시를 지시문 뒤에 붙인 최종 지시문
    var fullInstructions: String {
        guard !fewShot.isEmpty else { return instructions }
        let examples = fewShot.enumerated().map { i, e in "예시 \(i + 1)\n입력: \(e.input)\n출력: \(e.output)" }
        return instructions + "\n\n" + examples.joined(separator: "\n\n")
    }

    /// {{key}}를 값으로 바꾼다. 값이 없는 자리는 빈칸.
    func render(_ values: [String: String]) -> String {
        slotTemplate.replacing(/\{\{(\w+)\}\}/) { values[String($0.1)] ?? "" }
    }
}
