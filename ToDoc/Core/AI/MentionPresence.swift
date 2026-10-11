//
//  MentionPresence.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

/// 증상이 있었는지. AI 분석 결과와 기록장(Ledger)이 같이 쓴다. 원시값은 프롬프트 출력값과 같다
enum MentionPresence: String, Sendable {
    case present, absent, unclear
}
