import SwiftUI

/// Figma 1:5324. 현재 범위의 주치의 메시지·통증·증상 알림을 표시합니다.
struct NotificationView: View {
    @State private var state: NotificationScreenState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    init(state: NotificationScreenState = .init()) { _state = State(initialValue: state) }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("알림").appFont(.notificationTitle).accessibilityAddTraits(.isHeader)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward").font(.system(size: 17, weight: .semibold)).frame(width: 36, height: 36)
                    }.buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("이전").accessibilityIdentifier("notification.back")
                    Spacer()
                }
            }.frame(minHeight: 44).padding(.horizontal, AppSpacing.screenHorizontal).padding(.top, 31).padding(.bottom, 36)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
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
                                        Text(section.title).appFont(.notificationSection).accessibilityAddTraits(.isHeader)
                                        if section.hasUnread { Image("NotificationUnread").frame(width: 7, height: 7).accessibilityLabel("읽지 않은 알림 있음") }
                                    }.padding(.horizontal, 9)
                                    VStack(spacing: 14) { ForEach(section.items, id: \.id) { row($0) } }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, 32)
            }
        }.background(AppColors.background.ignoresSafeArea()).foregroundStyle(AppColors.Text.primary)
            .toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
            .onAppear { state.onReload?() }
            .onDisappear { state.onCancel?() }
    }
    private func row(_ item: NotificationRowData) -> some View {
        Button {
            state.onSelect?(item.id)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(item.icon.rawValue).resizable().scaledToFit().frame(width: 46, height: 46).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.tight) {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.tight)) : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.tight))
                    layout {
                        Text(item.title).appFont(.notificationCategory).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.timeLabel).appFont(.notificationTime).fixedSize(horizontal: true, vertical: false)
                    }.foregroundStyle(AppColors.Notification.metadata)
                    Text(item.body).appFont(.notificationBody).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if state.selectingID == item.id { ProgressView().accessibilityLabel("알림 확인 중") }
                }
            }.padding(.horizontal, 17).padding(.vertical, 19).frame(maxWidth: .infinity, alignment: .leading)
                .appSurface(.notification).contentShape(RoundedRectangle(cornerRadius: AppMetrics.Notification.cardRadius))
        }.buttonStyle(AppPressStyle()).disabled(state.loadState == .loading || state.selectingID != nil || state.onSelect == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.title), \(item.body), \(item.timeLabel)")
            .accessibilityValue(!item.isRead ? "읽지 않음" : "읽음")
            .accessibilityIdentifier("notification.item.\(item.id.uuidString)")
    }
    private var loadFailure: some View {
        VStack(spacing: AppSpacing.content) {
            Text(state.loadState == .unavailable ? "알림 연결을 준비 중이에요." : "알림을 불러오지 못했어요.").appTextStyle(.label)
            Button("다시 불러오기") { state.onReload?() }.appTextStyle(.label).disabled(state.onReload == nil).accessibilityIdentifier("notification.retry")
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

#Preview { NavigationStack { NotificationView() } }
