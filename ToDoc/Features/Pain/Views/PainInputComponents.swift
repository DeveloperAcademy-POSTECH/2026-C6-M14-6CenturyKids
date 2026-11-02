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

/// Figma 6-1·8: '가슴 외 2부위'
func painLocationSummary(_ locations: [BodyLocation]) -> String {
    guard let first = locations.first else { return "" }
    let name = painLocationName(first, among: locations)
    return locations.count > 1 ? "\(name) 외 \(locations.count - 1)부위" : name
}

/// Figma 규칙표의 통증 말 (Pain Scale과 같음)
func painScoreWord(_ score: Int) -> String {
    let words = ["안 아파요", "거의 안 느껴져요", "느껴져도 괜찮아요", "가끔 신경 쓰여요", "할 일은 할 수 있어요",
                 "하던 일을 멈춰요", "무시하기 힘들어요", "일상생활이 안 돼요", "너무 괴로워요", "참을 수가 없어요",
                 "가장 심하게 아파요"]
    return words[min(max(score, 0), 10)]
}

func painLocationBadge(_ location: BodyLocation) -> String? {
    switch location.bodyView {
    case .front: "앞"
    case .back: "뒤"
    case .unspecified: nil
    }
}

/// Figma Chip(더 보기): '외 N부위 ›'처럼 고른 부위 시트를 엽니다.
struct PainMoreLocationsChip: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).appTypography(.bodySmall).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .frame(width: 16, height: 16).accessibilityHidden(true)
            }
            .foregroundStyle(AppColors.Semantic.Text.sub)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .overlay(Capsule().strokeBorder(AppColors.Semantic.Border.default))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppActions.PressStyle())
        .accessibilityHint("고른 부위를 모두 봐요")
    }
}

/// 고른 부위 바텀시트(Figma 바텀시트 패턴). onRemove가 있으면 하나씩 빼고 모두 지울 수 있고, 없으면 읽기만 합니다.
struct PainLocationSheet: View {
    let locations: [BodyLocation]
    var onRemove: ((BodyLocation) -> Void)?
    var onRemoveAll: (() -> Void)?
    var onReselect: (() -> Void)?
    let onClose: () -> Void
    @State private var headerHeight: CGFloat = 79
    @State private var listHeight: CGFloat = 300
    @State private var bottomInset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Capsule().fill(AppColors.Semantic.Border.default).frame(width: 36, height: 5).accessibilityHidden(true)
                HStack(alignment: .top, spacing: 8) {
                    Color.clear.frame(width: 44, height: 44)
                    AppNavigation.PageTitle("선택한 부위 \(locations.count)개", alignment: .center)
                    AppActions.IconButton("닫기", icon: Image("PainSheetClose"), fill: AppColors.Pain.primarySubtle,
                                          action: onClose)
                }
            }
            .padding(.horizontal, 24).padding(.top, 10)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            // 부위가 많아 화면을 넘으면 시트 안에서 스크롤합니다
            ScrollView {
                list.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        // Figma 시트 아래 여백 40은 홈 표시줄 자리를 포함하므로, 시트가 더하는 아래 안전 영역만큼 뺍니다
        .presentationDetents([.height(headerHeight + listHeight - bottomInset)])
        .presentationDragIndicator(.hidden) // Figma 손잡이를 직접 그립니다
        .presentationCornerRadius(40)
        .presentationBackground(AppColors.Semantic.Background.surface)
    }

    private var list: some View {
        VStack(spacing: 8) {
            if onRemove == nil {
                Text("점수는 가장 아픈 부위를 기준으로 골라 주세요")
                    .appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            ForEach(locations, id: \.self) { row($0) }
            if let onRemoveAll {
                textButton("모두 지우기", typography: .label, action: onRemoveAll)
                    .padding(.top, 8).accessibilityIdentifier("pain.location.removeAll")
            }
            if let onReselect {
                textButton("부위 다시 고르기", typography: .body, action: onReselect)
                    .accessibilityIdentifier("pain.location.reselect")
            }
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 40)
    }

    private func row(_ location: BodyLocation) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(painLocationName(location)).appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                if let badge = painLocationBadge(location) {
                    Text(badge).appTypography(.caption).foregroundStyle(AppColors.Semantic.Text.sub)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(AppColors.Semantic.Background.secondary, in: Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName)")
            Spacer(minLength: 0)
            if let onRemove {
                Button { onRemove(location) } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(AppActions.PressStyle())
                .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName) 빼기")
            }
        }
        .padding(.leading, 16).padding(.trailing, 4)
        .frame(minHeight: 56)
        .background(AppColors.Semantic.Background.default, in: RoundedRectangle(cornerRadius: 16))
    }

    private func textButton(_ title: String, typography: AppTypography.Semantic,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).appTypography(typography).foregroundStyle(AppColors.Semantic.Text.action)
                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(AppActions.PressStyle())
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
