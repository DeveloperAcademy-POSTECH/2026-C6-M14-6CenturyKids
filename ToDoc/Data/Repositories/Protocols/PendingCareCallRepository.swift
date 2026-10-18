//
//  PendingCareCallRepository.swift
//  ToDoc
//
//  Created by seokho on 10/18/26.
//

import Foundation

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif

/// 케어콜에서 받은 답을 서버에 저장하기 전까지 폰에 남겨 두는 곳.
/// 앱이 꺼지거나(iOS는 강제 종료를 앱에 알리지 않아 답을 받을 때마다 남긴다) 저장이 실패해도, 다음에 케어콜에 들어갈 때 올린다
protocol PendingCareCallRepository {
    /// 같은 케어콜(id)이면 덮어쓴다
    func save(_ pending: PendingCareCall) throws
    /// 이 환자의 남은 기록 (통화 날짜가 이른 것부터). 읽을 수 없는 파일과 다른 환자의 기록은 건너뛴다
    func findAll(patientId: UUID) throws -> [PendingCareCall]
    /// 없으면 아무것도 하지 않는다
    func delete(id: UUID, patientId: UUID) throws
}

/// 아직 서버에 올리지 못한 케어콜 기록.
/// id: 케어콜 하나 (답마다 새로 남겨도 같은 파일). complete: 마무리 인사까지 마친 통화 (그날 기록이 있을 때 더할지 정한다)
struct PendingCareCall {
    let id: UUID
    let record: SymptomRecord
    let complete: Bool
}
