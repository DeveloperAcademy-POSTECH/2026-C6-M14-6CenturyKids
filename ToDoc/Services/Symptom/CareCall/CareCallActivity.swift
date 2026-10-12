//
//  CareCallActivity.swift
//  ToDoc
//
//  Created by seokho on 10/12/26.
//

/// 통화 중 지금 일어나는 일 (화면 표시용)
enum CareCallActivity: Equatable, Sendable {
    /// AI가 이 문장을 말하기 시작함
    case speaking(String)
    /// 환자 말을 듣는 중
    case listening
    /// 환자가 한 말. 이어서 분석한다
    case heard(String)
}
