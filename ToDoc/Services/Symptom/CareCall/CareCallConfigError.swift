//
//  CareCallConfigError.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation

enum CareCallConfigError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .missing(let name): "앱에 설정 파일 \(name)이 없습니다"
        }
    }
}
