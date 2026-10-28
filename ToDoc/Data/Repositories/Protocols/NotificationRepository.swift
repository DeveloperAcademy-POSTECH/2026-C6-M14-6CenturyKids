//
//  NotificationRepository.swift
//  ToDoc
//

import Foundation

#if canImport(ToDocDomain)
import ToDocDomain // 테스트 패키지에서는 Domain이 별도 모듈
#endif

protocol NotificationRepository {
    func save(
        notification: AppNotification,
        for patientId: UUID
    ) async throws
    
    func findById(_ id: UUID) async throws -> AppNotification?

    func findByUserId(
        _ userId: UUID
    ) async throws -> [AppNotification]

    func countUnreadByUserId(
        _ userId: UUID
    ) async throws -> Int

    func markAsRead(
        _ id: UUID
    ) async throws
}
