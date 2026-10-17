//
//  CareCalling.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

import Foundation

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
    /// 이 환자의 새 대화를 시작하고 첫 질문을 돌려준다 (모델을 불러온 뒤)
    func begin(patientId: UUID) throws -> CareCallTurn
    /// 답을 기다리는 지금 질문 (대화 전이면 nil)
    var current: CareCallTurn? { get }
    /// 지금 대화를 음성 통화로 이어 간다 (지금 질문부터 말한다). 끝까지 가면 저장할 기록을 돌려준다
    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome
    /// 문자 답 한 턴. 다음 질문(끝났으면 결과 포함)을 돌려준다
    func answer(_ text: String) async throws -> CareCallTurn
    /// 대화를 여기서 끝내고 결과를 돌려준다 (마쳤으면 그 결과, 아니면 끊긴 곳까지)
    func end() -> CareCallOutcome
    /// 통화를 바로 끝낸다. 진행 중인 run은 끊긴 곳까지의 기록으로 돌아온다
    func stop() async
}
