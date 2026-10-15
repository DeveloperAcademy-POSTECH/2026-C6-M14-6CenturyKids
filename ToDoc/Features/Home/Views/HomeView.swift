import SwiftUI

/// Figma 1:2762. 메시지와 미읽음 상태는 조회 결과만 표시합니다.
struct HomeView: View {
    @State private var state: HomeScreenState
    @State private var selectedMessage: HomeDoctorMessage?
    @Environment(\.dynamicTypeSize) private var typeSize
    private let onSelect: ((HomeDestination) -> Void)?
    init(state: HomeScreenState? = nil, onSelect: ((HomeDestination) -> Void)? = nil) {
        _state = State(initialValue: state ?? .init()); self.onSelect = onSelect
    }
    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 402
            ScrollView {
                VStack(spacing: 0) {
                    header.padding(.top, 20).padding(.bottom, 19)
                    if state.loadState != .loaded { loadStatus.padding(.horizontal, 24).padding(.bottom, 16) }
                    hero(scale: scale)
                    entryPanel.frame(minHeight: max(282, geometry.size.height - 83 - 348 * scale), alignment: .top)
                        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
                        .padding(.horizontal, 9)
                }.padding(.bottom, 12)
            }.background(LinearGradient(stops: [
                .init(color: Color(white: 249 / 255), location: 0),
                .init(color: Color(white: 249 / 255), location: 0.36538),
                .init(color: Color(white: 236 / 255), location: 0.48077),
                .init(color: Color(white: 236 / 255), location: 1)
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { state.onReload?() }
        .onDisappear { state.onCancel?() }
        .sheet(item: $selectedMessage) { message in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(message.body).appTextStyle(.label).textSelection(.enabled)
                        Text(message.createdAt, format: .dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ko_KR")))
                            .appTextStyle(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }.navigationTitle("주치의 메시지").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { selectedMessage = nil } } }
            }.environment(\.dynamicTypeSize, typeSize)
        }
    }
    private var header: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 4) {
                Text("내 주치의").homeText(12, style: .caption).foregroundStyle(Color(white: 93 / 255))
                Text(state.doctorName.map { "Dr. \($0)" } ?? (state.loadState == .loaded ? "연결된 의료진 없음" : (state.isLoading ? "확인 중" : "의료진 정보 확인 필요")))
                    .homeText(16, style: .heading).multilineTextAlignment(.center).padding(.horizontal, 60)
            }.frame(maxWidth: .infinity)
            Button { select(.notifications) } label: {
                Image("HomeBell").frame(width: 30, height: 30)
                    .overlay(alignment: .topTrailing) {
                        if state.showsUnreadBadge { Image("HomeUnreadBadge").frame(width: 7, height: 7).offset(x: -4, y: 5) }
                    }.frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(HomePressStyle()).disabled(!canOpen)
                .accessibilityLabel(state.showsUnreadBadge ? "알림, 읽지 않은 알림 있음" : "알림")
                .accessibilityIdentifier("home.notifications").padding(.trailing, 16)
        }
    }
    @ViewBuilder private func hero(scale: CGFloat) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 16) {
                messageBubble(scale: max(1, scale))
                Image("HakroDoctor").resizable().scaledToFill().frame(width: 290 * scale, height: 316 * scale).clipped().accessibilityHidden(true)
                symptomButton.padding(.horizontal, 17)
            }.padding(.bottom, 20)
        } else {
            ZStack(alignment: .topLeading) {
                Image("HakroDoctor").resizable().scaledToFill()
                    .frame(width: 290 * scale, height: 316 * scale).clipped()
                    .offset(x: 126 * scale, y: 82 * scale).accessibilityHidden(true)
                messageBubble(scale: scale).offset(x: 17 * scale)
                Image("HomeThoughtDotLarge").scaleEffect(x: -1, y: 1).scaleEffect(scale, anchor: .topLeading)
                    .offset(x: 227 * scale, y: 38 * scale).accessibilityHidden(true)
                Image("HomeThoughtDotSmall").rotationEffect(.degrees(180)).scaleEffect(scale, anchor: .topLeading)
                    .offset(x: 262 * scale, y: 63 * scale).accessibilityHidden(true)
                symptomButton.offset(x: 17 * scale, y: 270 * scale)
            }.frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 348 * scale)
        }
    }
    private func messageBubble(scale: CGFloat) -> some View {
        Button { selectedMessage = state.message } label: {
            Image("HomeThoughtBubble").scaleEffect(scale)
                .frame(width: 211.152 * scale, height: 141.597 * scale)
                .overlay {
                    Text(messageText).homeText(14, style: .label)
                        .foregroundStyle(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255))
                        .multilineTextAlignment(.center).lineLimit(typeSize.isAccessibilitySize ? 2 : 3)
                        .frame(width: 130 * scale).offset(y: 5 * scale)
                }
        }.buttonStyle(HomePressStyle()).disabled(state.message == nil)
            .accessibilityLabel(messageText).accessibilityHint(state.message == nil ? "" : "눌러서 메시지 전체 보기")
            .accessibilityIdentifier("home.message")
    }
    private var messageText: String {
        if let message = state.message { return message.body }
        if state.loadState == .loaded { return state.doctorName == nil ? "연결된 의료진이 없어요." : "아직 도착한 메시지가 없어요." }
        return state.isLoading ? "메시지를 확인하고 있어요." : "메시지 정보를 확인할 수 없어요."
    }
    private var symptomButton: some View {
        Button { select(.symptom) } label: {
            HStack(spacing: 2) {
                Text("증상 대화하기").homeText(16, style: .heading)
                Image("HomeConversationArrow").frame(width: 10.9326, height: 10.9326).accessibilityHidden(true)
            }.frame(height: typeSize.isAccessibilitySize ? nil : 15)
                .foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 24)
                .background(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255), in: RoundedRectangle(cornerRadius: 28))
                .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color(white: 128 / 255), lineWidth: 2) }
        }.buttonStyle(HomePressStyle()).disabled(!canOpen).accessibilityIdentifier("home.symptom")
    }
    private var entryPanel: some View {
        VStack(spacing: 12) {
            Button { select(.pain) } label: {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("복용 후 통증 기록").homeText(16, style: .heading).foregroundStyle(Color(red: 53 / 255, green: 77 / 255, blue: 9 / 255))
                        Text("약 복용 후 통증의 전후 비교").homeText(12, style: .caption).foregroundStyle(Color(red: 118 / 255, green: 151 / 255, blue: 58 / 255))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image("HomePrimaryArrow").frame(width: 12, height: 12).accessibilityHidden(true)
                }.padding(.horizontal, 16).padding(.vertical, 24)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 32))
            }.buttonStyle(HomePressStyle()).disabled(!canOpen).accessibilityIdentifier("home.pain")

        }.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 24)
    }
    @ViewBuilder private var loadStatus: some View {
        if state.isLoading { ProgressView("홈 정보를 불러오는 중") }
        else {
            VStack(spacing: 8) {
                Text(state.loadState == .unavailable ? "홈 정보 연결을 준비 중이에요." : "홈 정보를 불러오지 못했어요.")
                    .appTextStyle(.caption).multilineTextAlignment(.center)
                Button("다시 불러오기") { state.onReload?() }.appTextStyle(.label)
                    .disabled(state.onReload == nil).accessibilityIdentifier("home.retry")
            }
        }
    }
    private var canOpen: Bool { onSelect != nil }
    private func select(_ destination: HomeDestination) { onSelect?(destination) }
}
private struct HomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.contentShape(Rectangle()).opacity(configuration.isPressed ? 0.85 : 1) }
}
private struct HomeTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let style: AppTypography.Style
    init(size: CGFloat, style: AppTypography.Style) { _size = ScaledMetric(wrappedValue: size); self.style = style }
    func body(content: Content) -> some View { content.font(Font(style.font(at: size))).tracking(-size * 0.01) }
}
private extension View {
    func homeText(_ size: CGFloat, style: AppTypography.Style) -> some View { modifier(HomeTextStyle(size: size, style: style)) }
}
#Preview { NavigationStack { HomeView() } }
