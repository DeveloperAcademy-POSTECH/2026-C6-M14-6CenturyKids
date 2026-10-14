//
//  CareCalling.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

/// 케어콜 서비스(CareCallService)가 화면에 내주는 기능: 준비 단계와 통화.
/// 케어콜 ViewModel을 마이크·모델 없이 검증하려고 둔다 (CareCallService는 macOS 테스트 패키지에 넣을 수 없음)
protocol CareCalling: AnyObject {
    /// 마이크 권한을 받고 오디오 세션을 연다. 준비 단계는 차례로 부르고, 실패하면 같은 단계를 다시 부를 수 있다
    func requestMicrophone() async throws
    /// AI 모델과 음성 합성을 불러온다
    func loadModel() async throws
    /// 한국어 음성 인식을 준비한다 (처음 한 번 인식 에셋을 내려받는다)
    func prepareSpeech() async throws
    /// 통화를 끝까지 진행하고 저장할 기록을 돌려준다
    func run(onActivity: @escaping (CareCallActivity) -> Void) async throws -> CareCallOutcome
    /// 통화를 바로 끝낸다. 진행 중인 run은 끊긴 곳까지의 기록으로 돌아온다
    func stop() async
}
