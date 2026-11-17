import SwiftUI

/// Figma '통증 부위 선택 플로우' 1~5: 몸 그림은 한 면씩 보여 주고, 앞뒤를 바꿔도 고른 부위는 그대로입니다.
struct PainLocationSelectionView: View {
    let locations: [BodyLocation]
    var errorMessage: String?
    let onToggle: (BodyLocation) -> Void
    let onRemove: (BodyLocation) -> Void
    var onRemoveFromSheet: ((BodyLocation) -> Void)? = nil
    let onRemoveAll: () -> Void
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?

    @State private var bodyView = BodyView.front
    @State private var showsAllLocations = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var usesExpandedLayout: Bool { typeSize > .large }

    var body: some View {
        VStack(spacing: 0) {
            if usesExpandedLayout {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        bodyMapArea
                        rotateButton.frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 24)
                        selectedParts
                        footer
                    }
                }
            } else {
                header
                bodyMapArea.frame(maxHeight: .infinity)
                selectedParts
                footer
            }
        }
        .background(.white)
        .painBackButton(action: onClose, reservesSpace: usesExpandedLayout)
        .toolbar(.hidden, for: .navigationBar)
        // 시트에서 부위를 모두 빼면 시트를 닫고 처음 화면으로 돌아갑니다
        .onChange(of: locations.isEmpty) { _, isEmpty in
            if isEmpty { showsAllLocations = false }
        }
        .painSheet(isPresented: $showsAllLocations) {
            PainLocationSheet(locations: locations, onRemove: onRemoveFromSheet ?? onRemove, onRemoveAll: onRemoveAll,
                              onClose: { showsAllLocations = false })
        }
    }

    private var header: some View {
        PainHeader(title: "지금 어디가 아프세요?", description: "그림에서 아픈 부위를 선택해 주세요.")
            .padding(.top, 36)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let errorMessage {
                Text(errorMessage).font(.body).foregroundStyle(.red).padding(16)
            }
            PainInputFooter(title: "선택 부위 통증 고르기", isEnabled: !locations.isEmpty, onNext: onNext)
        }
    }

    /// Figma Body Map Area: 몸 그림은 가운데, 돌리기 버튼은 오른쪽 아래에 고정합니다.
    private var bodyMapArea: some View {
        PainBodyMap(bodyView: bodyView, locations: locations,
                    maximumWidth: usesExpandedLayout ? 272 : 227, onToggle: onToggle)
            .frame(maxWidth: .infinity, maxHeight: usesExpandedLayout ? nil : .infinity)
            .overlay(alignment: .bottomTrailing) {
                if !usesExpandedLayout {
                    rotateButton.padding(.bottom, 38)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
    }

    private var rotateButton: some View {
        AppActions.IconButton(bodyView == .front ? "뒷면 보기" : "앞면 보기",
                              icon: Image(systemName: "arrow.triangle.2.circlepath"),
                              type: .labeled, fill: AppColors.Pain.primarySubtle) {
            bodyView = bodyView == .front ? .back : .front
        }
        .foregroundStyle(AppColors.Semantic.Text.default)
        .accessibilityIdentifier("pain.location.rotate")
    }

    /// Figma Supporting Content: 고른 부위 칩 또는 안내 문구
    private var selectedParts: some View {
        Group {
            if locations.isEmpty {
                Text("부위를 1개 이상 골라주세요")
                    .appTypography(.label).foregroundStyle(AppColors.Semantic.Text.sub)
                    .multilineTextAlignment(.center)
            } else {
                PainSelectedLocationChips(locations: locations, onRemove: onRemove,
                                          onShowAll: { showsAllLocations = true })
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
    }
}

/// 고른 순서대로 두 개까지 보여 주고 나머지는 '외 N부위'로 묶습니다. 한 줄에 안 들어가면 하나만 보여 줍니다.
private struct PainSelectedLocationChips: View {
    let locations: [BodyLocation]
    let onRemove: (BodyLocation) -> Void
    let onShowAll: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize > .large {
            VStack(spacing: 8) { chips(shown: 2) }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(shown: 2) }
                HStack(spacing: 8) { chips(shown: 1) }
                VStack(spacing: 8) { chips(shown: 1) }
            }
        }
    }

    @ViewBuilder private func chips(shown: Int) -> some View {
        ForEach(locations.prefix(shown), id: \.self) { location in
            Button { onRemove(location) } label: {
                HStack(spacing: 4) {
                    Text(painLocationName(location, among: locations)).appTypography(.bodySmall)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .frame(width: 16, height: 16).accessibilityHidden(true)
                }
                .foregroundStyle(AppColors.Semantic.Text.inverse)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(AppColors.Pain.selectedLocationChip, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .fixedSize(horizontal: typeSize <= .large, vertical: true)
            .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName) 빼기")
        }
        if locations.count > shown {
            PainMoreLocationsChip(title: "외 \(locations.count - shown)부위", action: onShowAll)
                .fixedSize(horizontal: typeSize <= .large, vertical: true)
                .accessibilityIdentifier("pain.location.more")
        }
    }
}

/// 원본 신체 이미지(앞·뒤가 나란히 있음)에서 한 면만 잘라 보여 주고, 그 면의 부위 선택 영역만 겹칩니다.
/// 좌/우는 환자 기준입니다. 한쪽씩 선택해도 자동으로 both로 합치지 않습니다.
private struct PainBodyMap: View {
    private static let aspectRatio: CGFloat = 227 / 510
    let bodyView: BodyView
    let locations: [BodyLocation]
    let maximumWidth: CGFloat
    let onToggle: (BodyLocation) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Figma Body(Front/Back): 원본 이미지를 폭의 225%로 놓고 앞은 -10.54%, 뒤는 -112.5%만큼 옮겨 자릅니다.
            let side = width * 2.25
            let shift = width * (bodyView == .front ? 0.1054 : 1.125)
            ZStack(alignment: .topLeading) {
                // Figma Shadow: 발밑 131×13 (흐림 여백 포함 143×25), 몸 그림 크기에 맞춰 줄입니다
                Image("PainBodyShadow").resizable()
                    .frame(width: width * 143 / 227, height: width * 25 / 227)
                    .position(x: width / 2, y: geometry.size.height * 469.5 / 510)
                    .accessibilityHidden(true)
                ZStack(alignment: .topLeading) {
                    Image("PainBody").resizable().frame(width: side, height: side).accessibilityHidden(true)
                    ForEach(Self.regions.filter { $0.location.bodyView == bodyView }, id: \.location) { region in
                        regionButton(region, side: side)
                    }
                }
                .offset(x: -shift)
                .frame(width: width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .frame(maxWidth: maximumWidth, maxHeight: maximumWidth / Self.aspectRatio)
    }

    private func regionButton(_ region: Region, side: CGFloat) -> some View {
        let selected = locations.contains(region.location)
        return Button { onToggle(region.location) } label: {
            Color.clear.contentShape(Rectangle())
                .overlay {
                    if selected { Image("PainSelectedMarker").accessibilityHidden(true) }
                }
        }
        .buttonStyle(.plain)
        .frame(width: side * region.width, height: side * region.height)
        .position(x: side * region.x, y: side * region.y)
        .accessibilityLabel("\(painLocationName(region.location)) \(region.location.bodyView.displayName)")
        .accessibilityValue(selected ? "선택됨" : "선택하지 않음")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("pain.location.\(region.location.bodyPart.rawValue).\(region.location.bodySide.rawValue).\(region.location.bodyView.rawValue)")
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
    // 고른 표시점은 영역 가운데에 그려서, Figma 2~4의 표시점 자리(가슴·어깨·팔·다리·등허리)에 맞췄습니다.
    private static let regions: [Region] = [
        .init(.headFace, .center, .front, 0.27, 0.122, 0.11, 0.13),
        .init(.neck, .center, .front, 0.27, 0.217, 0.09, 0.06),
        .init(.shoulder, .right, .front, 0.192, 0.246, 0.08, 0.10),
        .init(.shoulder, .left, .front, 0.348, 0.246, 0.08, 0.10),
        .init(.chest, .center, .front, 0.27, 0.288, 0.14, 0.09),
        .init(.abdomen, .center, .front, 0.27, 0.387, 0.14, 0.095),
        .init(.pelvisButtocks, .center, .front, 0.27, 0.492, 0.17, 0.115),
        .init(.armHand, .right, .front, 0.1265, 0.4365, 0.11, 0.29),
        .init(.armHand, .left, .front, 0.4115, 0.4365, 0.11, 0.29),
        .init(.legFoot, .right, .front, 0.230, 0.748, 0.085, 0.40),
        .init(.legFoot, .left, .front, 0.306, 0.748, 0.085, 0.40),
        .init(.headFace, .center, .back, 0.727, 0.122, 0.11, 0.13),
        .init(.neck, .center, .back, 0.727, 0.217, 0.09, 0.06),
        .init(.shoulder, .left, .back, 0.649, 0.246, 0.08, 0.10),
        .init(.shoulder, .right, .back, 0.805, 0.246, 0.08, 0.10),
        .init(.backLowerBack, .center, .back, 0.7226, 0.380, 0.14, 0.17),
        .init(.pelvisButtocks, .center, .back, 0.727, 0.507, 0.17, 0.07),
        .init(.armHand, .left, .back, 0.5865, 0.4365, 0.11, 0.29),
        .init(.armHand, .right, .back, 0.8685, 0.4365, 0.11, 0.29),
        .init(.legFoot, .left, .back, 0.689, 0.748, 0.085, 0.40),
        .init(.legFoot, .right, .back, 0.765, 0.748, 0.085, 0.40)
    ]
}

#Preview("부위 고름") {
    @Previewable @State var locations: [BodyLocation] = [
        .init(bodyPart: .chest, bodySide: .center, bodyView: .front),
        .init(bodyPart: .shoulder, bodySide: .right, bodyView: .front),
        .init(bodyPart: .armHand, bodySide: .left, bodyView: .front),
        .init(bodyPart: .legFoot, bodySide: .right, bodyView: .front)
    ]
    PainLocationSelectionView(
        locations: locations,
        onToggle: { location in
            if let index = locations.firstIndex(of: location) { locations.remove(at: index) } else { locations.append(location) }
        },
        onRemove: { location in locations.removeAll { $0 == location } },
        onRemoveAll: { locations = [] },
        onNext: {}
    )
}
