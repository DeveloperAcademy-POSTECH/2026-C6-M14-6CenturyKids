import Foundation

/// readAt은 다이어그램의 필수 타입을 유지합니다. 미읽음 대체 날짜를 생성하지 않습니다.
nonisolated public struct AppNotification: Sendable {
    public let id: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let targetId: UUID
    public let createdAt: Date
    public let readAt: Date

    public init(id: UUID, type: NotificationType, title: String, body: String,
                targetId: UUID, createdAt: Date, readAt: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.targetId = targetId
        self.createdAt = createdAt
        self.readAt = readAt
    }
}
