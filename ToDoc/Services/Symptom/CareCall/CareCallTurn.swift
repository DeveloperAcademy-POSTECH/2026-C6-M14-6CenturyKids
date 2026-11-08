//
//  CareCallTurn.swift
//  ToDoc
//
//  Created by seokho on 10/15/26.
//

import Foundation

struct CareCallAnswerCompletion: Equatable, Sendable {
    enum Action: String, Sendable {
        case initial, unchanged, modified
    }

    let questionID: UUID
    let action: Action
}

struct CareCallTurn: Sendable {
    var utterance: String
    let number: CareCallConfig.Effect.Detail.Number?
    let outcome: CareCallOutcome?
    var progress: Double? = nil
    var asksMore = false
    var isLast = false
    var questionID: UUID? = nil
    var answerCompletion: CareCallAnswerCompletion? = nil
}
