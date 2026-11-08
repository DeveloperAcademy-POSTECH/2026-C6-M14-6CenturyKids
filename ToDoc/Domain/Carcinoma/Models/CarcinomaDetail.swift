nonisolated public struct CarcinomaDetail: Equatable, Sendable {
    public private(set) var carcinoma: CarcinomaType
    public private(set) var stage: CarcinomaStage

    public init(carcinoma: CarcinomaType, stage: CarcinomaStage) {
        self.carcinoma = carcinoma
        self.stage = stage
    }

    public mutating func updateCarcinomaType(_ type: CarcinomaType) {
        carcinoma = type
    }

    public mutating func updateStage(_ stage: CarcinomaStage) {
        self.stage = stage
    }
}
