//
//  LanguageModelError.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import Foundation

nonisolated enum LanguageModelError: LocalizedError {
    /// 이 기기에서 Apple Intelligence 모델을 쓸 수 없음 (지원하지 않는 기기, Apple Intelligence 꺼짐, 한국어 미지원)
    case modelMissing
    /// 모델이 아직 준비되지 않음 (내려받는 중 등). 잠시 후 다시 시도한다
    case modelNotReady

    var errorDescription: String? {
        switch self {
        case .modelMissing: "AI 모델이 없습니다. 이 기기에서는 AI 분석을 사용할 수 없어요."
        case .modelNotReady: "AI 모델이 아직 준비되지 않았습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}
