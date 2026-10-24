import SwiftUI

struct PainRecordNavigation {
    let showRecord: (PainRecord) -> Void
}

/// 환자 화면의 이동 경계. 새 ViewModel을 연결할 때 완성한 View를 주입합니다.
struct PatientFlowView: View {
    @State private var tab = Tab.home
    @State private var path: [HomeDestination] = []
    @State var home = HomeScreenState()
    var pain: (PainRecordNavigation) -> PainRecordView
    var preparePainDetail: (Date) -> Void
    var painDetail: () -> PainRecordDetailView
    var careCall: () -> CareCallFlowView = { .init() }
    var notifications: () -> NotificationView = { .init() }
    var records: () -> RecordsFlowView = { .init() }
    var settings: () -> SettingsFlowView

    init(
        pain: @escaping (PainRecordNavigation) -> PainRecordView,
        preparePainDetail: @escaping (Date) -> Void,
        painDetail: @escaping () -> PainRecordDetailView,
        careCall: @escaping () -> CareCallFlowView = { .init() },
        notifications: @escaping () -> NotificationView = { .init() },
        records: @escaping () -> RecordsFlowView = { .init() },
        settings: @escaping () -> SettingsFlowView
    ) {
        self.pain = pain
        self.preparePainDetail = preparePainDetail
        self.painDetail = painDetail
        self.careCall = careCall
        self.notifications = notifications
        self.records = records
        self.settings = settings
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                HomeView(state: home, onSelect: { path.append($0) })
                    .navigationDestination(for: HomeDestination.self) { destination in
                        Group {
                            switch destination {
                            case .pain:
                                pain(PainRecordNavigation(showRecord: { savedRecord in
                                    preparePainDetail(savedRecord.recordedDate)
                                    path = [.painDetail]
                                }))
                            case .painDetail: painDetail()
                            case .symptom: careCall()
                            case .notifications: notifications()
                            }
                        }.toolbar(.hidden, for: .tabBar)
                    }
            }.tabItem { Label("홈", systemImage: "house.fill") }.tag(Tab.home)
            records().tabItem { Label("기록확인", systemImage: "chart.bar.fill") }.tag(Tab.records)
            settings().tabItem { Label("설정", systemImage: "gearshape.fill") }.tag(Tab.settings)
        }
    }
}

#if DEBUG
extension PatientFlowView {
    @MainActor
    static func preview() -> Self {
        Self(
            pain: { _ in .preview() },
            preparePainDetail: { _ in },
            painDetail: { .init() },
            settings: {
                SettingsFlowView(
                    notifications: {
                        NotificationSettingsView(viewModel: NotificationSettingsViewModel())
                    }
                )
            }
        )
    }
}

#Preview { PatientFlowView.preview() }
#endif
