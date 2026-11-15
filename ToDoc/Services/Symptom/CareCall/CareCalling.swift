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
    /// 음성 통화에서 환자가 "다 말했어요"를 눌렀을 때. 그때까지 들은 말로 답을 받고 넘어간다
    func finishListening()
    func stop() async
    var canGoBack: Bool { get }
    func back() -> (turn: CareCallTurn, answer: String)?
    func continueAfterEmergency() -> CareCallTurn?
}

extension CareCalling {
    var appliedAnswerRevisions: Set<UUID>? { nil }
}
