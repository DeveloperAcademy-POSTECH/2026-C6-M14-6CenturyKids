#if DEBUG
import SwiftUI

/// Figma 1:5324. 식사·운동 알림은 현재 범위에서 제외합니다.
struct NotificationSectionPreview: View {
    enum Screen: String, CaseIterable { case filled, empty, loading, unavailable, failed }
    var initialScreen: Screen = .filled
    @State private var state = NotificationScreenState()
    @State private var message: String?

    var body: some View {
        NotificationView(state: state)
            .onAppear(perform: configure)
            .alert("알림 내용", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("닫기") { message = nil }
            } message: { Text(message ?? "") }
            .preferredColorScheme(.light)
    }
    private func configure() {
        state.loadState = switch initialScreen {
        case .filled, .empty: .loaded
        case .loading: .loading
        case .unavailable: .unavailable
        case .failed: .failed
        }
        state.sections = initialScreen == .filled ? [
            .init(id: "today", title: "오늘", hasUnread: true, items: [
                .init(id: UUID(), title: "학로 선생님의 메시지가 도착했어요", body: "명란 소금빵은 치료에 도움이 됩니다.", timeLabel: "2시간 전", isRead: false)
            ]),
            .init(id: "week", title: "최근 7일", hasUnread: false, items: [
                .init(id: UUID(), title: "통증 기록", body: "잊고 있던 돌발성 통증이 있나요?", timeLabel: "1일 전", isRead: true, icon: .pain),
                .init(id: UUID(), title: "증상 대화하기", body: "오늘 하루는 어땠나요? 증상을 기록해주세요", timeLabel: "2일 전", isRead: true, icon: .symptom)
            ])
        ] : []
        state.onSelect = { id in
            message = state.sections.flatMap(\.items).first(where: { $0.id == id })?.body
        }
        state.onReload = nil
    }
}
#Preview("알림 · 최신 Figma 1:5324") { NavigationStack { NotificationSectionPreview() } }
#Preview("알림 · 빈 상태") { NavigationStack { NotificationSectionPreview(initialScreen: .empty) } }
#Preview("알림 · 불러오는 중") { NavigationStack { NotificationSectionPreview(initialScreen: .loading) } }
#Preview("알림 · 연결 전") { NavigationStack { NotificationSectionPreview(initialScreen: .unavailable) } }
#Preview("알림 · 조회 실패") { NavigationStack { NotificationSectionPreview(initialScreen: .failed) } }
#endif
