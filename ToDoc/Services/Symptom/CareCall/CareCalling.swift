//
//  CareCalling.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

import Foundation

#if canImport(ToDocDomain)
import ToDocDomain
#endif

protocol CareCalling: AnyObject {
    func requestMicrophone() async throws
    func loadModel() async throws
    func prepareSpeech() async throws
    func begin(patientId: UUID, previous: SymptomRecord?) throws -> CareCallTurn
    var current: CareCallTurn? { get }
    var appliedAnswerRevisions: Set<UUID>? { get }
    var voiceOpening: String? { get }
    var progress: SymptomRecord? { get }
    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome
    func answer(_ text: String) async throws -> CareCallTurn
    func end() -> CareCallOutcome
    func stop() async
    var canGoBack: Bool { get }
    func back() -> (turn: CareCallTurn, answer: String)?
    func continueAfterEmergency() -> CareCallTurn?
}

extension CareCalling {
    var appliedAnswerRevisions: Set<UUID>? { nil }
}
