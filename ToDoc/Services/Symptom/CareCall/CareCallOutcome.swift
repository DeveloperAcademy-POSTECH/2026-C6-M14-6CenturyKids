//
//  CareCallOutcome.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

/// 통화가 끝난 결과. 기록 저장은 부른 쪽(Service)이 한다
enum CareCallOutcome: Sendable {
    /// 마무리 인사까지 마침. 저장할 그날 기록 (없음·모름 답 포함)
    case completed(SymptomRecord)
    /// 응급 안내 후 종료. 응급 기록 저장은 디자인 팀과 정할 때까지 보류
    case emergencyEnded
    /// stop·전화 등으로 중간에 끝남. 기록을 쓰지 않는다
    case interrupted
}
