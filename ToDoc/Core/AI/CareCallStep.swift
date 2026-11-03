//
//  CareCallStep.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

/// 한 증상 항목 안에서 지금 묻는 단계: 유무 → 횟수·시작(detail) → 부위. 원시값은 프롬프트에 그대로 들어간다
enum CareCallStep: String, Sendable {
    case presence, detail, location
}
