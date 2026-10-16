import Foundation

nonisolated public struct Doctor: Sendable {
    public let user: User
    public let code: String
    public let hospitalId: UUID

    public init(user: User, code: String, hospitalId: UUID) {
        self.user = user
        self.code = code
        self.hospitalId = hospitalId
    }
}
