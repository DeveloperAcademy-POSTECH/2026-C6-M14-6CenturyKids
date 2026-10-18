import SwiftUI

func painLocationName(_ location: BodyLocation) -> String {
    let side = location.bodySide == .center ? "" : location.bodySide.displayName + " "
    // Figma의 화면 문구만 적용합니다. 기존 Domain의 등·허리 분류는 보존합니다.
    let part = location.bodyPart == .backLowerBack ? "등" : location.bodyPart.displayName
    return side + part
}

/// 디자인에 명시된 두 예시 문구만 표시하며, 임의의 의료 분류 구간을 만들지 않습니다.
func painScoreDescription(_ score: Int) -> String? {
    switch score {
    case 2: "약한 통증"
    case 8: "강한 통증"
    default: nil
    }
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
            HStack(spacing: AppSpacing.compact) {
                ForEach(locations, id: \.self) { location in
                    HStack(spacing: AppSpacing.compact) {
                        Text(painLocationName(location, among: locations))
                            .appFont(onRemove == nil ? .captionRegular : .captionStrong)
                        if let onRemove {
                            Button { onRemove(location) } label: {
                                Text("×").font(AppTypography.painRemoveSymbol).frame(width: 28, height: 28)
                            }
                            .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName) 선택 삭제")
                        }
                    }
                    .padding(.leading, AppSpacing.item).padding(.trailing, onRemove == nil ? 12 : 6)
                    .frame(minHeight: 40)
                    .foregroundStyle(onRemove == nil ? AppColors.Text.primary : AppColors.Text.subdued)
                    .background(onRemove == nil ? AppColors.Pain.locationChip
                                : AppColors.Pain.removableLocationChip, in: Capsule())
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
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.item)) : AnyLayout(HStackLayout(spacing: AppSpacing.columnGap))
        layout {
            if let onPrevious {
                Button("이전", action: onPrevious)
                    .buttonStyle(AppButtonStyle(kind: typeSize.isAccessibilitySize ? .secondary : .back))
                    .disabled(!isPreviousEnabled)
            }
            Button { onNext?() } label: {
                AppForwardLabel(title: title, asset: "PainNext")
            }
            .buttonStyle(AppButtonStyle()).disabled(!isEnabled || onNext == nil)
            .accessibilityIdentifier("pain.next")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, 2)
    }
}
