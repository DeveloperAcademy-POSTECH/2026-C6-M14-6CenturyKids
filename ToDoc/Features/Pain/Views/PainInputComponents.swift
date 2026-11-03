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

/// Figma 캡슐(규칙표): 폭 144, 높이 144 + 점수 × 10, 글자 묶음은 바닥 동그라미 정가운데(바닥에서 39).
/// 0~3점은 화살표 자리를 남기려고 3점 높이(174)로 맞춥니다.
/// 먹기 전은 회색, 1시간 뒤는 라임 그라데이션이고 change(먹기 전 − 1시간 뒤)가 있으면 화살표를 그립니다.
struct PainScoreCapsule: View {
    let score: Int
    var isAfter = false
    var change: Int?

    /// 높이를 정하는 점수: 0~3점은 3점으로 봅니다.
    private var sizeScore: Int { min(max(score, 3), 10) }

    var body: some View {
        VStack(spacing: 24) {
            if isAfter, let change, change != 0 {
                PainChangeArrow(length: arrowLength, isDown: change > 0)
            }
            VStack(spacing: 8) {
                Text("\(score)점").appTypography(.headline)
                Text(painScoreWord(score)).appTypography(.bodySmall).lineLimit(1).fixedSize()
            }
            .foregroundStyle(isAfter ? AppColors.Semantic.Text.default : AppColors.Semantic.Text.sub)
        }
        .padding(.bottom, 39)
        .frame(width: 144, height: 144 + CGFloat(sizeScore) * 10, alignment: .bottom)
        .background {
            if isAfter {
                LinearGradient(colors: [AppColors.Semantic.Primary.default, AppColors.Semantic.Primary.default.opacity(0.25)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                AppColors.Semantic.Background.secondary
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 72))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isAfter ? "1시간 뒤" : "먹기 전") \(score)점, \(painScoreWord(score))")
    }

    /// 길이 = min(40, 남는 자리), 남는 자리 = 10 × 점수 − 11. 높이를 3점 이상으로 맞춰 가장 짧아도 19라 늘 보입니다.
    private var arrowLength: CGFloat {
        min(40, CGFloat(10 * sizeScore - 11))
    }
}

/// Figma 아래·위 화살표: 16 × 길이, 선 4, 끝 둥글게, 라임 그라데이션(옅음 → 진함). 올라감·내려감 모두 같은 색입니다.
private struct PainChangeArrow: View {
    let length: CGFloat
    let isDown: Bool

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 8, y: length))
            path.move(to: CGPoint(x: 1, y: length - 7))
            path.addLine(to: CGPoint(x: 8, y: length))
            path.addLine(to: CGPoint(x: 15, y: length - 7))
        }
        .stroke(LinearGradient(colors: [Color(red: 201 / 255, green: 243 / 255, blue: 128 / 255),
                                        Color(red: 113 / 255, green: 179 / 255, blue: 30 / 255)],
                               startPoint: .top, endPoint: .bottom),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        .frame(width: 16, height: length)
        .rotationEffect(.degrees(isDown ? 0 : 180))
        .accessibilityHidden(true)
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
            // 부위가 많아 화면을 넘을 때만 시트 안에서 스크롤합니다
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }.scrollBounceBehavior(.basedOnSize)
            }
        }
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

/// Figma Header(1177:16474): 제목 Bold 20과 설명 Medium 14를 가운데 정렬합니다.
struct PainHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title).appTypography(.title).foregroundStyle(AppColors.Semantic.Text.default)
                .accessibilityAddTraits(.isHeader)
            Text(description).appTypography(.label).foregroundStyle(AppColors.Semantic.Text.sub)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

/// Figma 바텀시트 패턴: 폭 전체, 위 모서리 40, 뒤는 검정 40% 막.
/// 시스템 시트는 iOS 26부터 좌우·아래가 떠 있는 모양이라 화면 위에 직접 그립니다.
private struct PainBottomSheet<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheet: () -> Sheet

    func body(content: Content) -> some View {
        content.overlay {
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    sheet()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.Semantic.Background.surface,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
                        .padding(.top, 60)
                        .gesture(DragGesture().onEnded { if $0.translation.height > 80 { isPresented = false } })
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) { isPresented = false }
                        .transition(.move(edge: .bottom))
                }
            }
            // Figma 시트 아래 여백 40은 홈 표시줄 자리를 포함합니다
            .ignoresSafeArea(edges: .bottom)
            .animation(.snappy, value: isPresented)
        }
    }
}

extension View {
    func painSheet<Sheet: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Sheet) -> some View {
        modifier(PainBottomSheet(isPresented: isPresented, sheet: content))
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
                if typeSize.isAccessibilitySize {
                    AppActions.Button("이전", kind: .secondary, action: onPrevious).disabled(!isPreviousEnabled)
                } else {
                    AppActions.BackButton(action: onPrevious).disabled(!isPreviousEnabled)
                }
            }
            // Figma Button: 꺼졌을 때 글자는 text/on-primary-disabled
            AppActions.Button(title) { onNext?() }
                .disabled(!isEnabled || onNext == nil)
                .accessibilityIdentifier("pain.next")
        }
        .padding(.horizontal, 24).padding(.bottom, 2)
    }
}
