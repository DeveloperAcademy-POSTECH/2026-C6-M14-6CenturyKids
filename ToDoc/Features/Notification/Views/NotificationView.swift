import SwiftUI

/// Figma 1:5324. 현재 범위의 주치의 메시지 알림을 표시합니다.
struct NotificationView: View {
    @State private var state: NotificationScreenState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    init(state: NotificationScreenState = .init()) { _state = State(initialValue: state) }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("알림").notificationText(20, bold: true).accessibilityAddTraits(.isHeader)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward").font(.system(size: 17, weight: .semibold)).frame(width: 36, height: 36)
                    }.buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("이전").accessibilityIdentifier("notification.back")
                    Spacer()
                }
            }.frame(minHeight: 44).padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 30)
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if let error = state.errorMessage { Text(error).appTextStyle(.caption) }
                    switch state.loadState {
                    case .loading: ProgressView("알림을 불러오는 중").frame(maxWidth: .infinity)
                    case .unavailable, .failed: loadFailure
                    case .loaded:
                        if state.sections.allSatisfy({ $0.items.isEmpty }) {
                            Text("아직 도착한 알림이 없어요.").appTextStyle(.label).frame(maxWidth: .infinity).padding(.vertical, 40)
                                .accessibilityIdentifier("notification.empty")
                        } else {
                            ForEach(state.sections) { section in
                                VStack(alignment: .leading, spacing: 18) {
                                    HStack(spacing: 6) {
                                        Text(section.title).notificationText(14, bold: true).accessibilityAddTraits(.isHeader)
                                        if section.hasUnread { Image("NotificationUnread").frame(width: 7, height: 7).accessibilityLabel("읽지 않은 알림 있음") }
                                    }.padding(.horizontal, 9)
                                    VStack(spacing: 14) { ForEach(section.items, id: \.id) { row($0) } }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 32)
            }
        }.background(Color(white: 248 / 255).ignoresSafeArea()).foregroundStyle(.black)
            .toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
            .onAppear { state.onReload?() }
            .onDisappear { state.onCancel?() }
    }
    private func row(_ item: NotificationRowData) -> some View {
        Button {
            state.onSelect?(item.id)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image("NotificationDoctor").resizable().scaledToFit().frame(width: 46, height: 46).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .top, spacing: 4))
                    layout {
                        Text(item.title).notificationText(10).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.timeLabel).notificationText(8).fixedSize(horizontal: true, vertical: false)
                    }.foregroundStyle(Color(white: 133 / 255))
                    Text(item.body).notificationText(14).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if state.selectingID == item.id { ProgressView().accessibilityLabel("알림 확인 중") }
                }
            }.padding(.horizontal, 17).padding(.vertical, 19).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 22)).contentShape(RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(NotificationPressStyle()).disabled(state.loadState == .loading || state.selectingID != nil || state.onSelect == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.title), \(item.body), \(item.timeLabel)")
            .accessibilityValue(!item.isRead ? "읽지 않음" : "읽음")
            .accessibilityIdentifier("notification.item.\(item.id.uuidString)")
    }
    private var loadFailure: some View {
        VStack(spacing: 16) {
            Text(state.loadState == .unavailable ? "알림 연결을 준비 중이에요." : "알림을 불러오지 못했어요.").appTextStyle(.label)
            Button("다시 불러오기") { state.onReload?() }.appTextStyle(.label).disabled(state.onReload == nil).accessibilityIdentifier("notification.retry")
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

private struct NotificationPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.85 : 1) }
}
private struct NotificationTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let bold: Bool
    init(size: CGFloat, bold: Bool) { _size = ScaledMetric(wrappedValue: size); self.bold = bold }
    func body(content: Content) -> some View {
        content.font(Font((bold ? AppTypography.Style.heading : .caption).font(at: size))).tracking(-size * 0.01)
    }
}
private extension View {
    func notificationText(_ size: CGFloat, bold: Bool = false) -> some View { modifier(NotificationTextStyle(size: size, bold: bold)) }
}
#Preview { NavigationStack { NotificationView() } }
