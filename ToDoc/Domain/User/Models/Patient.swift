import Foundation

nonisolated public struct Patient: Sendable {
    public let user: User
    public let doctorId: UUID?
    public let disease: CarcinomaDetail?

    public init(user: User, doctorId: UUID?, disease: CarcinomaDetail?) {
        self.user = user
        self.doctorId = doctorId
        self.disease = disease
    }
}
