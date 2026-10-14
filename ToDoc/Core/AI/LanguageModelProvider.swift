//
//  LanguageModelProvider.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//


#if canImport(CoreAI)
import CoreAILanguageModels
#endif
import Foundation
import FoundationModels

/// 케어콜 턴 분석에 쓰는 기기 안 언어 모델: Kanana 1.5 2.1B 8bit, iPhone 17(h18p)용으로 미리 컴파일한 것.
/// 모델은 git에 없고 Models/에 있을 때만 빌드 단계가 앱에 넣는다. 없거나 불러오지 못하면 대체 모델 없이 에러.
/// iOS 시뮬레이터 SDK에는 CoreAI가 없어(CoreAILM fork가 빈 모듈로 빌드됨) 시뮬레이터에서는 항상 modelMissing.
nonisolated enum LanguageModelProvider {
    static let kananaFolderName = "kanana-1.5-2.1b-instruct-ios-8bit-h18p"

    /// 메인 스레드 밖에서 불러온다. 기기 첫 로드는 특수화 캐시를 만드느라 1~2분 걸린다
    @concurrent
    static func loadKanana() async throws -> any LanguageModel {
        #if canImport(CoreAI)
        guard let url = Bundle.main.url(forResource: kananaFolderName, withExtension: nil) else {
            throw LanguageModelError.modelMissing
        }
        do {
            return try await CoreAILanguageModel(resourcesAt: url, mode: .eager)
        } catch {
            throw LanguageModelError.loadFailed(error)
        }
        #else
        throw LanguageModelError.modelMissing
        #endif
    }
}
