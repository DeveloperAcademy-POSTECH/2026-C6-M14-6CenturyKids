//
//  LanguageModelProvider.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//


import Foundation
import FoundationModels

/// 케어콜 턴 분석에 쓰는 기기 안 언어 모델: Apple Intelligence 기본 모델 (Foundation Models).
/// 쓸 수 없는 기기·설정이면 대체 모델 없이 에러. 시뮬레이터는 Mac에서 Apple Intelligence를 켜면 쓸 수 있다.
nonisolated enum LanguageModelProvider {
    static func systemModel() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            guard model.supportsLocale(Locale(identifier: "ko_KR")) else { throw LanguageModelError.modelMissing }
            return model
        case .unavailable(.modelNotReady):
            throw LanguageModelError.modelNotReady
        case .unavailable:
            throw LanguageModelError.modelMissing
        }
    }
}
