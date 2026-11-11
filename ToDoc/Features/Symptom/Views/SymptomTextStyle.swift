import SwiftUI

struct SymptomTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight = .regular) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(Font(AppTypography.Style.caption.font(at: size)).weight(weight))
    }
}
