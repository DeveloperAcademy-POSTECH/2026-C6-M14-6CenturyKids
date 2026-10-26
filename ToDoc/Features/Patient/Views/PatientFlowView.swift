import SwiftUI

struct PainRecordNavigation {
    let showRecord: (PainRecord) -> Void
}

struct CareCallNavigation {
    let home: () -> Void
    let showRecord: (Date) -> Void
}

/// 환자 화면의 이동 경계. 새 ViewModel을 연결할 때 완성한 View를 주입합니다.
struct PatientFlowView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = Tab.home
    @State private var path: [HomeDestination] = []
    @State private var showsPrevisit = false
    @State private var previsitSession = PrevisitSession()
    let home: HomeScreenState
    var onHomeContextChange: (Bool, Bool) -> Void
    var onReloadHome: (() -> Void)?
    var previsit: (PrevisitSession) -> PrevisitFlowView
    var pain: (PainRecordNavigation) -> PainRecordView
    var preparePainDetail: (Date) -> Void
    var painDetail: () -> PainRecordDetailView
    var careCall: (CareCallNavigation) -> CareCallFlowView = { _ in .init() }
    var prepareSymptomDetail: (Date) -> Void = { _ in }
    var symptomDetail: () -> SymptomRecordDetailView = { .init() }
    var notifications: () -> NotificationView = { .init() }
    var records: () -> RecordsFlowView = { .init() }
    var settings: () -> SettingsFlowView

    init(
        home: HomeScreenState? = nil,
        onHomeContextChange: @escaping (Bool, Bool) -> Void = { _, _ in },
        onReloadHome: (() -> Void)? = nil,
        previsit: @escaping (PrevisitSession) -> PrevisitFlowView = { .init(session: $0) },
        pain: @escaping (PainRecordNavigation) -> PainRecordView,
        preparePainDetail: @escaping (Date) -> Void,
        painDetail: @escaping () -> PainRecordDetailView,
        careCall: @escaping (CareCallNavigation) -> CareCallFlowView = { _ in .init() },
        prepareSymptomDetail: @escaping (Date) -> Void = { _ in },
        symptomDetail: @escaping () -> SymptomRecordDetailView = { .init() },
        notifications: @escaping () -> NotificationView = { .init() },
        records: @escaping () -> RecordsFlowView = { .init() },
        settings: @escaping () -> SettingsFlowView
    ) {
        self.home = home ?? .init()
        self.onHomeContextChange = onHomeContextChange
        self.onReloadHome = onReloadHome
        self.previsit = previsit
        self.pain = pain
        self.preparePainDetail = preparePainDetail
        self.painDetail = painDetail
        self.careCall = careCall
        self.prepareSymptomDetail = prepareSymptomDetail
        self.symptomDetail = symptomDetail
        self.notifications = notifications
        self.records = records
        self.settings = settings
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                HomeView(state: home, onSelect: { path.append($0) },
                         onPrevisit: { showsPrevisit = true }, onReload: onReloadHome)
                    .navigationDestination(for: HomeDestination.self) { destination in
                        Group {
                            switch destination {
                            case .pain:
                                pain(PainRecordNavigation(showRecord: { savedRecord in
                                    preparePainDetail(savedRecord.recordedDate)
                                    path = [.painDetail]
                                }))
                            case .painDetail: painDetail()
                            case .symptom:
                                careCall(CareCallNavigation(home: {
                                    path.removeAll(); tab = .home
                                }, showRecord: { date in
                                    prepareSymptomDetail(date)
                                    path = [.symptomDetail]
                                }))
                            case .symptomDetail: symptomDetail()
                            case .notifications: notifications()
                            }
                        }.toolbar(.hidden, for: .tabBar)
                    }
            }.tabItem { Label("홈", systemImage: "house.fill") }.tag(Tab.home)
            records().tabItem { Label("기록확인", systemImage: "chart.bar.fill") }.tag(Tab.records)
            settings().tabItem { Label("설정", systemImage: "gearshape.fill") }.tag(Tab.settings)
        }
        .fullScreenCover(isPresented: $showsPrevisit, onDismiss: { previsitSession.pause() }) {
            NavigationStack { previsit(previsitSession) }
        }
        .onAppear { updateHomeContext() }
        .onChange(of: isHomeVisible) { updateHomeContext() }
        .onChange(of: scenePhase) { updateHomeContext() }
        .onDisappear { onHomeContextChange(false, false) }
    }

    private var isHomeVisible: Bool { tab == .home && path.isEmpty && !showsPrevisit }
    private func updateHomeContext() {
        onHomeContextChange(isHomeVisible, scenePhase == .active)
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
