//
//  NotificationRepository.swift
//  ToDoc
//

import Foundation

protocol NotificationRepository: Repository
where Entity == AppNotification {
    func save(
        notification: AppNotification,
        for patientId: UUID
    ) async throws

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
