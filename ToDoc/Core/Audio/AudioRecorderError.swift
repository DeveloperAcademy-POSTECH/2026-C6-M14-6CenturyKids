//
//  AudioRecorderError.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

enum AudioRecorderError: LocalizedError {
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "마이크 권한이 없습니다. 설정에서 마이크 접근을 허용해 주세요."
        }
    }
}
