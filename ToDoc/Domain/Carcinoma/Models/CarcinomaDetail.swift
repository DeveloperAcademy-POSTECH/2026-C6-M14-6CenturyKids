import Foundation

nonisolated public struct CarcinomaDetail: Equatable, Sendable {
    public private(set) var carcinoma: CarcinomaType
    public private(set) var stage: CarcinomaStage
    public private(set) var otherName: String?

    public init(carcinoma: CarcinomaType, stage: CarcinomaStage, otherName: String? = nil) {
        self.carcinoma = carcinoma
        self.stage = stage
        self.otherName = Self.normalizedOtherName(otherName, for: carcinoma)
    }

    public var carcinomaDisplayName: String { otherName ?? carcinoma.displayName }

    public mutating func updateCarcinomaType(_ type: CarcinomaType, otherName: String? = nil) {
        carcinoma = type
        self.otherName = Self.normalizedOtherName(otherName, for: type)
    }

    public mutating func updateStage(_ stage: CarcinomaStage) {
        self.stage = stage
    }

    private static func normalizedOtherName(_ name: String?, for type: CarcinomaType) -> String? {
        guard type == .other, let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
