import SwiftUI

/// Figma의 홈 비율을 유지하고, 작은 화면에서는 하단 카드까지 스크롤합니다.
struct HomeView: View {
    private let state: HomeScreenState
    @ScaledMetric private var textScale: CGFloat = 1
    private let onSelect: ((HomeDestination) -> Void)?
    private let onPrevisit: (() -> Void)?
    private let onReload: (() -> Void)?
    private let isVisible: Bool
    init(state: HomeScreenState? = nil, onSelect: ((HomeDestination) -> Void)? = nil, onPrevisit: (() -> Void)? = nil, onReload: (() -> Void)? = nil, isVisible: Bool = true) {
        self.state = state ?? .init(); self.onSelect = onSelect
        self.onPrevisit = onPrevisit
        self.onReload = onReload
        self.isVisible = isVisible
    }
    var body: some View {
        GeometryReader { geometry in
            let headerHeight = max(44, 40.4 * textScale) + 36
            let heroHeight = 408 * geometry.size.width / 402
            let bottomInset = geometry.safeAreaInsets.bottom
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    header
                        .frame(height: headerHeight - 36, alignment: .top)
                        .padding(.top, 17).padding(.bottom, 19)
                    hero(width: geometry.size.width, height: heroHeight)
                    entryPanel
                        .padding(.bottom, bottomInset)
                        .frame(maxWidth: .infinity,
                               minHeight: max(0, geometry.size.height + bottomInset - headerHeight - heroHeight),
                               alignment: .top)
                        .background(AppColors.surface, in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
                        .padding(.horizontal, 9)
                }
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height + bottomInset, alignment: .top)
            }
            // 패널 배경은 탭바 뒤까지 연결하고, 카드는 위의 여백으로 가리지 않습니다.
            .ignoresSafeArea(.container, edges: .bottom)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .background(AppGradients.homeBackground.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)

    }
    private var header: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 4) {
                Text("내 주치의").appFont(.homeCaption).foregroundStyle(AppColors.Home.doctorCaption)
                    .frame(minHeight: 15.6 * textScale)
                Text(doctorTitle)
                    .appFont(.homeTitle).lineLimit(1).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center).padding(.horizontal, 60)
                    .frame(minHeight: 20.8 * textScale)
            }.frame(maxWidth: .infinity)
                .accessibilityValue(state.isLoading ? "홈 정보를 불러오는 중" : "")
            Button { select(.notifications) } label: {
                Image("HomeBell").frame(width: 30, height: 30)
                    .overlay(alignment: .topTrailing) {
                        if state.showsUnreadBadge { Image("HomeUnreadBadge").frame(width: 7, height: 7).offset(x: -4, y: 5) }
                    }.frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(AppPressStyle()).disabled(!canOpen)
                .accessibilityLabel(state.showsUnreadBadge ? "알림, 읽지 않은 알림 있음" : "알림")
                .accessibilityIdentifier("home.notifications").padding(.trailing, 16)
        }
    }
    private var doctorTitle: String {
        // 탭 재진입 조회 중에도 마지막으로 확인한 '연결 없음' 표시를 유지합니다.
        if case .unlinked = state.doctor.connection { return "연결된 의료진 없음" }
        return state.doctorTitle
    }
    private func hero(width: CGFloat, height: CGFloat) -> some View {
        let scale = height / 408
        let horizontalScale = width / 402
        return ZStack(alignment: .topLeading) {
            // Figma 홈 목업의 학로 위치에 맞추고, 영상 원본 비율로 상하 여백을 없앱니다.
            HomeHakroVideo(isVisible: isVisible)
                .frame(width: 348 * scale, height: 348 * 708 / 720 * scale)
                .offset(x: 60 * horizontalScale, y: 113 * scale).accessibilityHidden(true)
            ZStack(alignment: .topLeading) {
                messageBubble(scale: scale).offset(x: 17 * horizontalScale)
                Image("HomeThoughtDotLarge").scaleEffect(x: -1, y: 1).scaleEffect(scale, anchor: .topLeading)
                    .offset(x: width / 2 + 26 * horizontalScale, y: 38 * scale).accessibilityHidden(true)
                Image("HomeThoughtDotSmall").rotationEffect(.degrees(180)).scaleEffect(scale, anchor: .topLeading)
                    .offset(x: width / 2 + 61 * horizontalScale, y: 63 * scale).accessibilityHidden(true)
            }
            .modifier(HomeThoughtFloat(isVisible: isVisible, scale: scale))
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            previsitButton.padding(.leading, 17 * horizontalScale).padding(.bottom, 10 * scale)
        }
        .clipped()
    }
    private func messageBubble(scale: CGFloat) -> some View {
        Image("HomeThoughtBubble").resizable()
            .frame(width: 211.152 * scale, height: 141.597 * scale)
            .shadow(color: .black.opacity(0.025), radius: 7 * scale, x: 0, y: 3 * scale)
            .overlay {
                Text(state.greeting?.text ?? HomeGreeting.all[0].text).appFont(.homeMessage).foregroundStyle(AppColors.gray)
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.75)
                    .frame(width: 130 * scale, height: 111 * scale).offset(y: 4.7 * scale)
            }
            .accessibilityIdentifier("home.greeting")
    }
    private var previsitButton: some View {
        Button { onPrevisit?() } label: {
            HStack(spacing: 1.578) {
                Text("진료 전 기록").appFont(.homeTitle)
                Image("HomeConversationArrow").frame(width: 10.9326, height: 10.9326).accessibilityHidden(true)
            }.frame(minHeight: 16 * textScale)
                .foregroundStyle(AppColors.Text.inverse)
                .padding(.horizontal, 16).padding(.vertical, 24)
                .background(AppColors.gray, in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28).stroke(
                        LinearGradient(colors: [AppColors.Home.previsitBorder, Color(white: 88 / 255)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 2)
                }
        }.buttonStyle(AppPressStyle()).disabled(onPrevisit == nil).accessibilityIdentifier("home.previsit")
            .accessibilityHint(onPrevisit == nil ? "진료 전 기록 연결을 준비 중이에요" : "")
    }
    private var entryPanel: some View {
        VStack(spacing: 14) {
            HomeEntryCard(title: "통증 기록하기", subtitle: "돌발성 통증과 약 복용 후 통증 기록", primary: true) { select(.pain) }
                .disabled(!canOpen).accessibilityIdentifier("home.pain")
            HomeEntryCard(title: "증상 대화하기", subtitle: "오늘 하루 증상 기록하기", primary: false) { select(.symptom(autoStartVoice: false)) }
                .disabled(!canOpen).accessibilityIdentifier("home.symptom")
        }.padding(.horizontal, AppSpacing.item).padding(.top, AppSpacing.item).padding(.bottom, AppSpacing.section)
            // 조회 상태는 레이아웃에 참여하지 않아 캐릭터와 카드 위치가 고정됩니다.
            .overlay(alignment: .bottom) {
                if !state.isLoading, state.statusMessage != nil {
                    loadStatus.padding(.horizontal, 12).padding(.bottom, 2)
                }
            }
    }
    private var loadStatus: some View {
        HStack(spacing: 8) {
            Text(state.statusMessage ?? "")
                .appFont(.homeCaption).lineLimit(1).minimumScaleFactor(0.8)
            if let onReload {
                Button("다시 불러오기", action: onReload).appFont(.homeCaption)
                    .accessibilityIdentifier("home.retry")
            }
        }
    }
    private var canOpen: Bool { onSelect != nil }
    private func select(_ destination: HomeDestination) { onSelect?(destination) }
}

/// 왕복 6.4초 동안 기준 화면에서 3pt를 천천히 오르내립니다.
private struct HomeThoughtFloat: ViewModifier {
    let isVisible: Bool
    let scale: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floats = false

    private var canFloat: Bool { isVisible && scenePhase == .active && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .offset(y: floats ? 3 * scale : 0)
            .scaleEffect(floats ? 1.002 : 1, anchor: .topLeading)
            // 앱 활성화 시에도 같은 말풍선을 유지하고, 등장 전환은 적용하지 않습니다.
            .transition(.identity)
            .task(id: canFloat) {
                resetFloat()
                guard canFloat else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    floats = true
                }
            }
            .onDisappear { resetFloat() }
    }

    private func resetFloat() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { floats = false }
    }
}

/// 홈 진입 카드의 동일한 제목/설명/화살표 구조. 기능 콜백은 부모가 결정합니다.
private struct HomeEntryCard: View {
    let title: String
    let subtitle: String
    let primary: Bool
    @ScaledMetric private var textHeight: CGFloat = 41
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.tight) {
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    Text(title).appFont(.homeTitle).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(primary ? AppColors.Home.primaryTitle : AppColors.Home.secondaryTitle)
                    Text(subtitle).appFont(.homeCaption).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(primary ? AppColors.Home.primaryCaption : AppColors.Home.secondaryCaption)
                }.frame(maxWidth: .infinity, minHeight: textHeight, alignment: .leading)
                Image(primary ? "HomePrimaryArrow" : "HomeSecondaryArrow")
                    .frame(width: 12, height: 12).accessibilityHidden(true)
            }.padding(.horizontal, AppSpacing.content)
                .padding(.vertical, 24)
                .appSurface(primary ? .homePrimary : .homeSecondary)
        }.buttonStyle(AppPressStyle())
    }
}

#if DEBUG
#Preview("홈 · 준비 상태") { NavigationStack { HomeView(onSelect: { _ in }) } }
#endif
