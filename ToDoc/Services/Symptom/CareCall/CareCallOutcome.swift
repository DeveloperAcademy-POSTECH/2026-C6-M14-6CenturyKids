//
//  CareCallOutcome.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif

/// 통화가 끝난 결과. 기록 저장은 부른 쪽(케어콜 ViewModel)이 한다
enum CareCallOutcome: Sendable {
    /// 마무리 인사까지 마침. 저장할 그날 기록 (없음·모름 답 포함)
    case completed(SymptomRecord)
    /// 응급 안내 후 종료. 응급 전까지 답한 기록 + 응급으로 끝낸 말("[검토 필요] 응급 안내로 종료: …", 위기 표현은 "위기 표현: …")
    case emergencyEnded(SymptomRecord)
    /// stop·전화·오류로 중간에 끝남. 끊긴 곳까지 답한 기록 (묻지 못한 증상은 없음, 받은 답이 없으면 nil)
    case interrupted(SymptomRecord?)
}
