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
        PainChipFlowLayout(centered: onRemove == nil) {
            ForEach(locations, id: \.self) { location in
                HStack(spacing: 8) {
                    Text(painLocationName(location, among: locations)).appTextStyle(.caption)
                        .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 선택 순서를 유지하면서 사용 가능한 너비를 넘는 칩은 다음 줄에 놓습니다.
private struct PainChipFlowLayout: Layout {
    let centered: Bool
    private let spacing: CGFloat = 8

    private struct Row {
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealWidth = subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width }
            + spacing * CGFloat(max(0, subviews.count - 1))
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? idealWidth
        let rows = rows(width: width, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height }
            + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (centered ? max(0, (bounds.width - row.width) / 2) : 0)
            for size in row.sizes {
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var row = Row()
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            if !row.sizes.isEmpty, row.width + spacing + size.width > width {
                result.append(row)
                row = Row()
            }
            row.width += (row.sizes.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.sizes.append(size)
        }
        if !row.sizes.isEmpty { result.append(row) }
        return result
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
