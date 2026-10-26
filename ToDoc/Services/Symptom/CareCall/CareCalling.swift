//
//  CareCalling.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

import Foundation

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif

/// 케어콜 서비스(CareCallService)가 화면에 내주는 기능: 준비 단계, 대화(음성 통화·문자 답).
/// 대화 하나를 begin으로 시작하면 음성과 문자를 오가도 같은 대화를 이어 간다.
/// 케어콜 ViewModel을 마이크·모델 없이 검증하려고 둔다 (CareCallService는 macOS 테스트 패키지에 넣을 수 없음)
protocol CareCalling: AnyObject {
    /// 마이크 권한을 받고 오디오 세션을 연다. 준비 단계는 차례로 부르고, 실패하면 같은 단계를 다시 부를 수 있다
    func requestMicrophone() async throws
    /// AI 모델과 음성 합성을 불러온다
    func loadModel() async throws
    /// 한국어 음성 인식을 준비한다 (처음 한 번 인식 에셋을 내려받는다)
    func prepareSpeech() async throws
    /// 이 환자의 새 대화를 시작하고 첫 질문을 돌려준다 (모델을 불러온 뒤). previous는 오늘 이미 저장된 기록:
    /// 있으면 다시 거는 통화로 "달라졌거나 새로 불편한 점"을 묻고, 말한 증상과 그 기록에 없는 항목만 묻는다
    func begin(patientId: UUID, previous: SymptomRecord?) throws -> CareCallTurn
    /// 답을 기다리는 지금 질문 (대화 전이면 nil)
    var current: CareCallTurn? { get }
    /// 지금까지 받은 답으로 만든 기록 (대화 전이거나 받은 답이 없으면 nil). 앱이 꺼져도 남도록 답마다 폰에 남길 때 쓴다
    var progress: SymptomRecord? { get }
    /// 지금 대화를 음성 통화로 이어 간다 (지금 질문부터 말한다). 끝까지 가면 저장할 기록을 돌려준다
    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome
    /// 문자 답 한 턴. 다음 질문(끝났으면 결과 포함)을 돌려준다
    func answer(_ text: String) async throws -> CareCallTurn
    /// 대화를 여기서 끝내고 결과를 돌려준다 (마쳤으면 그 결과, 아니면 끊긴 곳까지)
    func end() -> CareCallOutcome
    /// 통화를 바로 끝낸다. 진행 중인 run은 끊긴 곳까지의 기록으로 돌아온다
    func stop() async
    /// 마지막 답을 지우고 그 질문으로 돌아갈 수 있음 (대화 중이고 받은 답이 있음)
    var canGoBack: Bool { get }
    /// 마지막 답을 지우고 그 질문으로 돌아간다. 그때 환자가 한 말도 돌려준다
    func back() -> (turn: CareCallTurn, answer: String)?
    /// 응급 안내로 끝난 대화를 응급 전 질문부터 잇는다 (응급으로 남긴 말은 기록에 그대로)
    func continueAfterEmergency() -> CareCallTurn?
}
