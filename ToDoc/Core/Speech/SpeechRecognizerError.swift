//
//  SpeechRecognizerError.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

enum SpeechRecognizerError: LocalizedError {
    case koreanUnsupported
    case noAudioFormat

    var errorDescription: String? {
        switch self {
        case .koreanUnsupported: "이 기기에서는 한국어 음성 인식을 지원하지 않습니다."
        case .noAudioFormat: "음성 인식에 쓸 오디오 형식을 정할 수 없습니다."
        }
    }
}
