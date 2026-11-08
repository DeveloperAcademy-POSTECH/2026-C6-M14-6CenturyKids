import Foundation

/// 연관 의사 목록은 조회 시점의 스냅샷이며 역방향 관계를 자동 갱신하지 않습니다.
nonisolated public struct Hospital: Sendable {
    public let id: UUID
    public let name: String
    public let code: String
    public private(set) var address: String
    public let latitude: Double?
    public let longitude: Double?

    public init(id: UUID, name: String, code: String, address: String, latitude: Double?, longitude: Double?) throws {
        let validName = try DomainValidation.name(name, maximum: 30)
        let validAddress = try DomainValidation.address(address)
        self.id = id
        self.name = validName
        self.code = code
        self.address = validAddress
        self.latitude = latitude
        self.longitude = longitude
    }

    public mutating func updateAddress(_ address: String) throws {
        self.address = try DomainValidation.address(address)
    }
}
