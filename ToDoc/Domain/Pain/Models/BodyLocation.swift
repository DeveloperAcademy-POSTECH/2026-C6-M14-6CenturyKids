nonisolated public struct BodyLocation: Hashable, Sendable {
    public let bodyPart: BodyPart
    public let bodySide: BodySide
    public let bodyView: BodyView

    public init(bodyPart: BodyPart, bodySide: BodySide, bodyView: BodyView) {
        self.bodyPart = bodyPart
        self.bodySide = bodySide
        self.bodyView = bodyView
    }
}
