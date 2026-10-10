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

enum AudioRecorderEvent {
    /// 다른 앱(전화, Siri 등)이 오디오를 가져가 마이크가 멈췄다
    case interrupted
    /// 끼어들기가 끝나 마이크를 다시 켰다
    case resumed
    /// 마이크를 다시 켜지 못했다
    case failed(Error)
}

enum AudioRecorderError: LocalizedError {
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "마이크 권한이 없습니다. 설정에서 마이크 접근을 허용해 주세요."
        }
    }
}
