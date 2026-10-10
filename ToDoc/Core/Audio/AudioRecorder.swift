//
//  AudioRecorder.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import AVFAudio

/// 마이크 입력. 음성 인식(SpeechRecognizer 구현체)이 마이크 소리를 받을 때 쓴다.
protocol AudioRecorder: AnyObject {
    /// 전화·Siri 등으로 마이크가 멈추거나 다시 켜질 때 불린다
    var onEvent: ((AudioRecorderEvent) -> Void)? { get set }

    /// 마이크 권한을 요청하고 오디오 세션을 연다. 반환: 마이크 입력 형식 (음성 인식 형식을 고를 때 쓴다)
    func prepare() async throws -> AVAudioFormat

    /// 마이크를 켠다. `onBuffer`는 오디오 스레드에서 불린다.
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws

    func stop()
}
