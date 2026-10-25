import SwiftUI

/// 환자 화면의 이동 경계. 새 ViewModel을 연결할 때 완성한 View를 주입합니다.
struct PatientFlowView: View {
    @Environment(AppRouter.self) private var router
    
    @State private var tab = Tab.home
    @State private var path: [HomeDestination] = []
    @State var home = HomeScreenState()
    var pain: () -> PainRecordView
    var careCall: (Bool) -> CareCallFlowView = { _ in .init() }
    var notifications: () -> NotificationView = { .init() }
    var records: () -> RecordsFlowView = { .init() }
    var settings: () -> SettingsFlowView = { .init() }

    init(
        pain: @escaping () -> PainRecordView,
        careCall: @escaping (Bool) -> CareCallFlowView = { _ in .init() },
        notifications: @escaping () -> NotificationView = { .init() },
        records: @escaping () -> RecordsFlowView = { .init() },
        settings: @escaping () -> SettingsFlowView = { .init() }
    ) {
        self.pain = pain
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
                            case .pain: pain()
                            case .symptom(let autoStartVoice):
                                careCall(autoStartVoice)
                            case .notifications: notifications()
                            }
                        }.toolbar(.hidden, for: .tabBar)
                    }
            }.tabItem { Label("홈", systemImage: "house.fill") }.tag(Tab.home)
            records().tabItem { Label("기록확인", systemImage: "chart.bar.fill") }.tag(Tab.records)
            settings().tabItem { Label("설정", systemImage: "gearshape.fill") }.tag(Tab.settings)
        }
        .onChange(of: router.pendingDeepLink, initial: true) { _, deepLink in
            guard let deepLink else { return }
            
            switch deepLink {
            case .careCall(let autoStartVoice):
                tab = .home
                path = [.symptom(autoStartVoice: autoStartVoice)]
            }
            
            router.pendingDeepLink = nil
        }
    }
}

#if DEBUG
#Preview { PatientFlowView(pain: { .preview() })
        .environment(AppRouter())
}
#endif
