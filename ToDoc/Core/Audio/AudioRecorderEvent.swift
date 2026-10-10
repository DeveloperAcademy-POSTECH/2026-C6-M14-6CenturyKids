//
//  AudioRecorderEvent.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

/// 마이크 입력 중 생긴 일 (AudioRecorder.onEvent)
enum AudioRecorderEvent {
    /// 다른 앱(전화, Siri 등)이 오디오를 가져가 마이크가 멈췄다
    case interrupted
    /// 끼어들기가 끝나 마이크를 다시 켰다
    case resumed
    /// 마이크를 다시 켜지 못했다
    case failed(Error)
}
