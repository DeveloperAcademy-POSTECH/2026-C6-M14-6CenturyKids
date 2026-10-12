//
//  LanguageModelError.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import Foundation

nonisolated enum LanguageModelError: LocalizedError {
    /// 앱에 모델이 들어 있지 않음 (모델 없이 빌드)
    case modelMissing
    /// 모델은 있지만 불러오지 못함 (지원하지 않는 기기, 메모리 부족, 기기 캐시 손상 등)
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelMissing: "AI 모델이 없습니다. 이 기기에서는 AI 분석을 사용할 수 없어요."
        case .loadFailed: "AI 모델을 불러오지 못했습니다. 지원하지 않는 기기이거나 메모리가 부족할 수 있어요."
        }
    }
}
