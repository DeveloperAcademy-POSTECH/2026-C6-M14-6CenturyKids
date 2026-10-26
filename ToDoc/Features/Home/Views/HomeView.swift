import SwiftUI

/// 홈은 스크롤 없이 표시하고, 조회 상태와 기능 콜백을 보존합니다.
struct HomeView: View {
    private let state: HomeScreenState
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var textScale: CGFloat = 1
    private let onSelect: ((HomeDestination) -> Void)?
    private let onPrevisit: (() -> Void)?
    private let onReload: (() -> Void)?
    init(state: HomeScreenState? = nil, onSelect: ((HomeDestination) -> Void)? = nil, onPrevisit: (() -> Void)? = nil, onReload: (() -> Void)? = nil) {
        self.state = state ?? .init(); self.onSelect = onSelect
        self.onPrevisit = onPrevisit
        self.onReload = onReload
    }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650 || typeSize >= .xxLarge
            let cardPadding: CGFloat = compact ? 16 : 24
            let topPadding: CGFloat = compact ? 8 : 17
            let bottomPadding: CGFloat = compact ? 10 : 19
            let headerHeight = max(44, 40.4 * textScale) + topPadding + bottomPadding
            let panelHeight = 2 * (40.4 * textScale + 2 * cardPadding) + 50 + (showsLoadStatus ? 14 + max(20, 15.6 * textScale) : 0)
            let heroHeight = max(0, min(408 * geometry.size.width / 402,
                                       geometry.size.height - headerHeight - panelHeight))
            VStack(spacing: 0) {
                header.padding(.top, topPadding).padding(.bottom, bottomPadding)
                hero(width: geometry.size.width, height: heroHeight)
                entryPanel(verticalPadding: cardPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AppColors.surface, in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
                    .padding(.horizontal, 9)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(AppGradients.homeBackground.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)

    }
    private var header: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 4) {
                Text("내 주치의").appFont(.homeCaption).foregroundStyle(AppColors.Home.doctorCaption)
                Text(state.doctorTitle)
                    .appFont(.homeTitle).lineLimit(1).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center).padding(.horizontal, 60)
            }.frame(maxWidth: .infinity)
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
    private func hero(width: CGFloat, height: CGFloat) -> some View {
        let scale = height / 408
        let horizontalScale = width / 402
        return ZStack(alignment: .topLeading) {
            Image("HakroDoctor").resizable().scaledToFill()
                .frame(width: 290 * scale, height: 316 * scale).clipped()
                .offset(x: width - 276 * scale, y: 82 * scale).accessibilityHidden(true)
            messageBubble(scale: scale).offset(x: 17 * horizontalScale)
            Image("HomeThoughtDotLarge").scaleEffect(x: -1, y: 1).scaleEffect(scale, anchor: .topLeading)
                .offset(x: width / 2 + 26 * horizontalScale, y: 38 * scale).accessibilityHidden(true)
            Image("HomeThoughtDotSmall").rotationEffect(.degrees(180)).scaleEffect(scale, anchor: .topLeading)
                .offset(x: width / 2 + 61 * horizontalScale, y: 63 * scale).accessibilityHidden(true)
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
            .overlay {
                Text(state.greeting?.text ?? HomeGreeting.all[0].text).appFont(.homeMessage).foregroundStyle(AppColors.gray)
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.75)
                    .frame(width: 130 * scale, height: 111 * scale).offset(y: 4.7 * scale)
            }
            .accessibilityIdentifier("home.greeting")
    }
    private var previsitButton: some View {
        Button { onPrevisit?() } label: {
            HStack(spacing: 2) {
                Text("진료 전 기록").appFont(.homeTitle)
                Image("HomeConversationArrow").frame(width: 10.9326, height: 10.9326).accessibilityHidden(true)
            }.frame(height: typeSize >= .xxLarge ? nil : 15)
                .foregroundStyle(AppColors.Text.inverse)
                .padding(.horizontal, 16).padding(.vertical, 24)
                .background(AppColors.gray, in: RoundedRectangle(cornerRadius: 28))
                .overlay { RoundedRectangle(cornerRadius: 28).stroke(AppColors.Home.previsitBorder, lineWidth: 2) }
        }.buttonStyle(AppPressStyle()).disabled(onPrevisit == nil).accessibilityIdentifier("home.previsit")
            .accessibilityHint(onPrevisit == nil ? "진료 전 기록 연결을 준비 중이에요" : "")
    }
    private func entryPanel(verticalPadding: CGFloat) -> some View {
        VStack(spacing: 14) {
            HomeEntryCard(title: "복용 후 통증 기록", subtitle: "약 복용 후 통증의 전후 비교", primary: true, verticalPadding: verticalPadding) { select(.pain) }
                .disabled(!canOpen).accessibilityIdentifier("home.pain")
            HomeEntryCard(title: "증상 대화하기", subtitle: "오늘 하루 증상 기록하기", primary: false, verticalPadding: verticalPadding) { select(.symptom(autoStartVoice: false)) }
                .disabled(!canOpen).accessibilityIdentifier("home.symptom")
            if showsLoadStatus { loadStatus }
        }.padding(.horizontal, AppSpacing.item).padding(.top, AppSpacing.item).padding(.bottom, AppSpacing.section)
    }
    private var showsLoadStatus: Bool {
        state.statusMessage != nil
    }
    @ViewBuilder private var loadStatus: some View {
        if state.isLoading { ProgressView("홈 정보를 불러오는 중").appFont(.homeCaption) }
        else {
            HStack(spacing: 8) {
                Text(state.statusMessage ?? "")
                    .appFont(.homeCaption).lineLimit(1).minimumScaleFactor(0.8)
                if let onReload {
                    Button("다시 불러오기", action: onReload).appFont(.homeCaption)
                        .accessibilityIdentifier("home.retry")
                }
            }
        }
    }
    private var canOpen: Bool { onSelect != nil }
    private func select(_ destination: HomeDestination) { onSelect?(destination) }
}
/// 홈 진입 카드의 동일한 제목/설명/화살표 구조. 기능 콜백은 부모가 결정합니다.
private struct HomeEntryCard: View {
    let title: String
    let subtitle: String
    let primary: Bool
    var verticalPadding: CGFloat = 24
    @ScaledMetric private var textHeight: CGFloat = 40.4
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
                .padding(.vertical, verticalPadding)
                .appSurface(primary ? .homePrimary : .homeSecondary)
        }.buttonStyle(AppPressStyle())
    }
}

#if DEBUG
#Preview("홈 · 준비 상태") { NavigationStack { HomeView(onSelect: { _ in }) } }
#endif
