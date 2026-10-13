import Foundation

/// 읽은 시각입니다. nil은 미읽음이며 대체 날짜를 생성하지 않습니다. (2026-10-12 확정 계약)
nonisolated public struct AppNotification: Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let targetId: UUID
    public let createdAt: Date
    public let readAt: Date?

    public init(id: UUID, type: NotificationType, title: String, body: String,
                targetId: UUID, createdAt: Date, readAt: Date?) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.targetId = targetId
        self.createdAt = createdAt
        self.readAt = readAt
    }
}
