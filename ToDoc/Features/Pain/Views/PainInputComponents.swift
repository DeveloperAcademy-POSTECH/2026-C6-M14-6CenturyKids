import SwiftUI

struct PainTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight = .medium) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }
    func body(content: Content) -> some View {
        content.font(Font(AppTypography.Style.caption.font(at: size)).weight(weight))
    }
}

func painLocationName(_ location: BodyLocation) -> String {
    let side = location.bodySide == .center ? "" : location.bodySide.displayName + " "
    return side + location.bodyPart.displayName
}

func painLocationName(_ location: BodyLocation, among locations: [BodyLocation]) -> String {
    let duplicates = locations.contains { $0.bodyPart == location.bodyPart && $0.bodySide == location.bodySide && $0.bodyView != location.bodyView }
    return painLocationName(location) + (duplicates ? " (\(location.bodyView.displayName))" : "")
}

struct PainLocationChips: View {
    let locations: [BodyLocation]
    var onRemove: ((BodyLocation) -> Void)?
    var body: some View {
        ViewThatFits(in: .horizontal) {
            chips.fixedSize(horizontal: true, vertical: false)
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
        .frame(maxWidth: .infinity, alignment: onRemove == nil ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var chips: some View {
            HStack(spacing: 8) {
                ForEach(locations, id: \.self) { location in
                    HStack(spacing: 8) {
                        Text(painLocationName(location, among: locations)).appTextStyle(.caption)
                        if let onRemove {
                            Button { onRemove(location) } label: {
                                Text("×").font(.system(size: 18)).frame(width: 28, height: 28)
                            }
                            .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName) 선택 삭제")
                        }
                    }
                    .padding(.leading, 12).padding(.trailing, onRemove == nil ? 12 : 6)
                    .frame(minHeight: 40)
                    .foregroundStyle(Color(white: 79 / 255))
                    .background(Color(white: onRemove == nil ? 240 / 255 : 231 / 255), in: Capsule())
                    .accessibilityElement(children: .contain)
                }
            }
    }
}

struct PainInputFooter: View {
    var title = "다음"
    var isEnabled = false
    var isPreviousEnabled = true
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 20))
        layout {
            if let onPrevious {
                Button("이전", action: onPrevious)
                    .buttonStyle(AppButtonStyle(kind: typeSize.isAccessibilitySize ? .secondary : .back))
                    .disabled(!isPreviousEnabled)
            }
            Button { onNext?() } label: {
                HStack {
                    Color.clear.frame(width: 12, height: 12)
                    Spacer(minLength: 8)
                    Text(title)
                    Spacer(minLength: 8)
                    Image("CareConversationNext").frame(width: 12, height: 12).accessibilityHidden(true)
                }
            }
            .buttonStyle(AppButtonStyle()).disabled(!isEnabled || onNext == nil)
            .accessibilityIdentifier("pain.next")
        }
        .padding(.horizontal, 24).padding(.bottom, 2)
    }
}
