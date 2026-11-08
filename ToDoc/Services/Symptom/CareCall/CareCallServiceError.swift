//
//  CareCallServiceError.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

import Foundation

enum CareCallServiceError: LocalizedError {
    /// 준비(모델 로드)를 마치기 전에 통화를 시작함
    case notPrepared

    var errorDescription: String? {
        switch self {
        case .notPrepared: "케어콜 준비가 끝나지 않았습니다"
        }
    }
}
