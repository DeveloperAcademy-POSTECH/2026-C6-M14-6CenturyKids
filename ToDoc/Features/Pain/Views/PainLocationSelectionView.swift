import SwiftUI

struct PainLocationSelectionView: View {
    let locations: [BodyLocation]
    var errorMessage: String?
    let onToggle: (BodyLocation) -> Void
    let onRemove: (BodyLocation) -> Void
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    AppHeader(title: "지금 어디가 아프세요?", description: "그림에서 아픈 부위를 눌러 주세요")
                        .padding(.top, typeSize.isAccessibilitySize ? 44 : 0)
                    PainBodySelection(locations: locations, onToggle: onToggle)
                        .padding(.top, 81)
                    PainLocationChips(locations: locations, onRemove: onRemove)
                        .padding(.horizontal, 24).padding(.top, 18)
                }
                .padding(.bottom, 24)
            }
            if let errorMessage {
                Text(errorMessage).font(.body).foregroundStyle(.red).padding(16)
            }
            PainInputFooter(title: "선택 부위 통증 점수 고르기", isEnabled: !locations.isEmpty, onNext: onNext)
        }
        .background(.white)
        .overlay(alignment: .topLeading) {
            if let onClose {
                Button(action: onClose) { Image("PainBack").frame(width: 40, height: 40) }
                    .buttonStyle(.plain).padding(.leading, 24).padding(.top, 5)
                    .accessibilityLabel("통증 기록에서 돌아가기")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// 원본 신체 이미지 위에 Domain 부위 선택 영역만 겹칩니다.
/// 좌/우는 환자 기준입니다. 한쪽씩 선택해도 자동으로 both로 합치지 않습니다.
private struct PainBodySelection: View {
    let locations: [BodyLocation]
    let onToggle: (BodyLocation) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Image("PainBody").resizable().scaledToFit().accessibilityHidden(true)
                ForEach(Self.regions, id: \.location) { region in
                    let selected = locations.contains(region.location)
                    Button { onToggle(region.location) } label: {
                        Color.clear.contentShape(Rectangle())
                            .overlay {
                                if selected { Image("PainSelectedMarker").frame(width: 25, height: 25) }
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: geometry.size.width * region.width, height: geometry.size.height * region.height)
                    .position(x: geometry.size.width * region.x, y: geometry.size.height * region.y)
                    .accessibilityLabel("\(painLocationName(region.location)) \(region.location.bodyView.displayName)")
                    .accessibilityValue(selected ? "선택됨" : "선택하지 않음")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                    .accessibilityIdentifier("pain.location.\(region.location.bodyPart.rawValue).\(region.location.bodySide.rawValue).\(region.location.bodyView.rawValue)")
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private struct Region {
        let location: BodyLocation
        let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        init(_ part: BodyPart, _ side: BodySide, _ view: BodyView,
             _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
            location = .init(bodyPart: part, bodySide: side, bodyView: view)
            self.x = x; self.y = y; self.width = width; self.height = height
        }
    }

    // 원본 1:1957의 이미지 좌표에 정규화한 조작 영역입니다. 의료 진단 영역이 아닙니다.
    private static let regions: [Region] = [
        .init(.headFace, .center, .front, 0.27, 0.105, 0.11, 0.13),
        .init(.neck, .center, .front, 0.27, 0.20, 0.09, 0.06),
        .init(.shoulder, .right, .front, 0.18, 0.235, 0.08, 0.10),
        .init(.shoulder, .left, .front, 0.36, 0.235, 0.08, 0.10),
        .init(.chest, .center, .front, 0.27, 0.277, 0.14, 0.09),
        .init(.abdomen, .center, .front, 0.27, 0.37, 0.14, 0.095),
        .init(.pelvisButtocks, .center, .front, 0.27, 0.475, 0.17, 0.115),
        .init(.armHand, .right, .front, 0.105, 0.425, 0.11, 0.29),
        .init(.armHand, .left, .front, 0.433, 0.425, 0.11, 0.29),
        .init(.legFoot, .right, .front, 0.224, 0.735, 0.085, 0.40),
        .init(.legFoot, .left, .front, 0.312, 0.735, 0.085, 0.40),
        .init(.headFace, .center, .back, 0.727, 0.105, 0.11, 0.13),
        .init(.neck, .center, .back, 0.727, 0.20, 0.09, 0.06),
        .init(.shoulder, .left, .back, 0.637, 0.235, 0.08, 0.10),
        .init(.shoulder, .right, .back, 0.817, 0.235, 0.08, 0.10),
        .init(.backLowerBack, .center, .back, 0.727, 0.369, 0.14, 0.17),
        .init(.pelvisButtocks, .center, .back, 0.727, 0.49, 0.17, 0.07),
        .init(.armHand, .left, .back, 0.565, 0.425, 0.11, 0.29),
        .init(.armHand, .right, .back, 0.890, 0.425, 0.11, 0.29),
        .init(.legFoot, .left, .back, 0.683, 0.735, 0.085, 0.40),
        .init(.legFoot, .right, .back, 0.771, 0.735, 0.085, 0.40)
    ]
}
