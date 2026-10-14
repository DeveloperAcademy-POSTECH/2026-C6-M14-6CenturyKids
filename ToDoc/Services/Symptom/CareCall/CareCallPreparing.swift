//
//  CareCallPreparing.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

/// 케어콜 준비 단계 (CareCallService). 차례로 부르고, 실패하면 같은 단계를 다시 부를 수 있다.
/// 준비 화면 ViewModel을 마이크·모델 없이 검증하려고 둔다 (CareCallService는 macOS 테스트 패키지에 넣을 수 없음)
protocol CareCallPreparing: AnyObject {
    /// 마이크 권한을 받고 오디오 세션을 연다
    func requestMicrophone() async throws
    /// AI 모델과 음성 합성을 불러온다
    func loadModel() async throws
    /// 한국어 음성 인식을 준비한다 (처음 한 번 인식 에셋을 내려받는다)
    func prepareSpeech() async throws
}
