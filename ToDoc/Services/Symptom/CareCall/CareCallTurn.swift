//
//  CareCallTurn.swift
//  ToDoc
//
//  Created by seokho on 10/15/26.
//

struct CareCallTurn: Sendable {
    var utterance: String
    let number: CareCallConfig.Effect.Detail.Number?
    let outcome: CareCallOutcome?
    var progress: Double? = nil
    var asksMore = false
    var isLast = false
}
