import Foundation

nonisolated public struct SymptomEntry: Sendable {
    public static let detailLimit = 300

    public let id: UUID
    public let symptomType: SymptomType
    public let presence: SymptomPresence
    public let bodyPart: BodyPart?
    public let bodySide: BodySide?
    public let rawLocationText: String?
    public private(set) var durationMinutes: Int?
    public private(set) var occurrenceCount: Int?
    public private(set) var detail: String?

    public init(id: UUID, symptomType: SymptomType, presence: SymptomPresence, bodyPart: BodyPart?, bodySide: BodySide?,
                rawLocationText: String? = nil, durationMinutes: Int?, occurrenceCount: Int?, detail: String?) throws {
        try Self.validate(durationMinutes, in: 10...1440, error: .invalidDuration)
        try Self.validate(occurrenceCount, in: 1...100, error: .invalidOccurrenceCount)
        try Self.validateDetail(detail)
        self.id = id
        self.symptomType = symptomType
        self.presence = presence
        self.bodyPart = bodyPart
        self.bodySide = bodySide
        self.rawLocationText = rawLocationText
        self.durationMinutes = durationMinutes
        self.occurrenceCount = occurrenceCount
        self.detail = detail
    }

    public mutating func updateDurationMinutes(_ durationMinutes: Int) throws {
        try Self.validate(durationMinutes, in: 10...1440, error: .invalidDuration)
        self.durationMinutes = durationMinutes
    }

    public mutating func updateOccurrenceCount(_ occurrenceCount: Int) throws {
        try Self.validate(occurrenceCount, in: 1...100, error: .invalidOccurrenceCount)
        self.occurrenceCount = occurrenceCount
    }

    public mutating func updateDetail(_ detail: String) throws {
        try Self.validateDetail(detail)
        self.detail = detail
    }

    private static func validate(_ value: Int?, in range: ClosedRange<Int>, error: SymptomValueError) throws {
        if let value, !range.contains(value) { throw error }
    }

    private static func validateDetail(_ detail: String?) throws {
        if let detail, detail.count > detailLimit { throw SymptomValueError.detailTooLong }
    }
}
