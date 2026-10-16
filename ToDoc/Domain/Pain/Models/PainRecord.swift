import Foundation

nonisolated public struct PainRecord: Sendable {
    public let id: UUID
    public let patientId: UUID
    public let recordedDate: Date
    public private(set) var location: [BodyLocation]
    public let painBefore: Int
    public let painAfter: Int
    public var painChange: Int { painBefore - painAfter }

    public init(id: UUID, patientId: UUID, recordedDate: Date, location: [BodyLocation], painBefore: Int, painAfter: Int) throws {
        guard !location.isEmpty else { throw PainLocationValidationError.empty }
        try Self.validatePain(painBefore)
        try Self.validatePain(painAfter)
        self.id = id
        self.patientId = patientId
        self.recordedDate = recordedDate
        var seen = Set<BodyLocation>()
        self.location = location.filter { seen.insert($0).inserted }
        self.painBefore = painBefore
        self.painAfter = painAfter
    }

    public mutating func addLocation(_ location: BodyLocation) {
        guard !self.location.contains(location) else { return }
        self.location.append(location)
    }

    /// 최소 한 부위를 유지하며, 없는 부위를 제거해도 기록은 변하지 않습니다.
    public mutating func removeLocation(_ location: BodyLocation) {
        guard self.location.count > 1 else { return }
        self.location.removeAll { $0 == location }
    }

    private static func validatePain(_ value: Int) throws {
        guard value >= 0 else { throw PainRecordValueError.belowMinimum }
        guard value <= 10 else { throw PainRecordValueError.aboveMaximum }
    }
}
