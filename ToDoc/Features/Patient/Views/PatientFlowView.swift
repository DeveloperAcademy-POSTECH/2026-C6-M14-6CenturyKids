import SwiftUI

struct PainRecordNavigation {
    let showRecord: (PainRecord) -> Void
}

struct CareCallNavigation {
    let home: () -> Void
    let showRecord: (Date) -> Void
    
    var autoStartVoice: Bool = false
}

/// 환자 화면의 이동 경계. 새 ViewModel을 연결할 때 완성한 View를 주입합니다.
struct PatientFlowView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
  
    @State private var tab = Tab.home
    @State private var path: [HomeDestination] = []
    @State private var showsPrevisit = false
    @State private var showsPrevisitPrompt = false
    @State private var showsPrevisitDiscard = false
    /// 바텀시트·작성 화면이 닫힌 뒤 열 화면 (닫는 중에는 다른 화면을 띄울 수 없다)
    @State private var previsitNext: PrevisitNext?
    @State private var previsitSession = PrevisitSession()
  
    let home: HomeScreenState
    var onHomeContextChange: (Bool, Bool) -> Void
    var onReloadHome: (() -> Void)?
    var previsit: (PrevisitSession) -> PrevisitFlowView
    var previsitLetters: PrevisitLetterViewModel
  
    var pain: (PainRecordNavigation) -> PainRecordView
    var preparePainDetail: (Date) -> Void
    var painDetail: () -> PainRecordDetailView
  
    var careCall: (CareCallNavigation) -> CareCallFlowView = { _ in .init() }
    var prepareSymptomDetail: (Date) -> Void = { _ in }
    var symptomDetail: () -> SymptomRecordDetailView = { .init() }
    var notifications: () -> NotificationView = { .init() }
    var records: () -> RecordsFlowView = { .init() }
    var settings: () -> SettingsFlowView

    @MainActor
    init(
        home: HomeScreenState? = nil,
        onHomeContextChange: @escaping (Bool, Bool) -> Void = { _, _ in },
        onReloadHome: (() -> Void)? = nil,
        previsit: @escaping (PrevisitSession) -> PrevisitFlowView = { .init(session: $0) },
        previsitLetters: PrevisitLetterViewModel? = nil,
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
        self.previsitLetters = previsitLetters ?? .init()
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
                         onPrevisit: { showsPrevisitPrompt = true }, onReload: onReloadHome)
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
                            case .previsitLetters:
                                PrevisitLetterListView(viewModel: previsitLetters) { path.append(.previsitLetter($0)) }
                            case .previsitLetter(let id):
                                PrevisitLetterView(viewModel: previsitLetters, id: id, patientName: home.patientName ?? "")
                                    .onDisappear { if previsitLetters.notice == .saved { previsitLetters.clearNotice() } }
                            }
                        }.toolbar(.hidden, for: .tabBar)
                    }
            }.tabItem { Label("홈", systemImage: "house.fill") }.tag(Tab.home)
            records().tabItem { Label("기록확인", systemImage: "chart.bar.fill") }.tag(Tab.records)
            settings().tabItem { Label("설정", systemImage: "gearshape.fill") }.tag(Tab.settings)
        }
        .onChange(of: router.pendingDeepLink, initial: true) { _, deepLink in
            guard let deepLink else { return }
            // 바텀시트가 떠 있으면 먼저 닫는다. 닫는 중에는 다른 화면을 띄울 수 없어, 닫힌 뒤 openPrevisitNext가 이어서 연다
            guard !showsPrevisitPrompt else {
                previsitNext = nil
                showsPrevisitPrompt = false
                return
            }
            open(deepLink)
        }
        .sheet(isPresented: $showsPrevisitPrompt, onDismiss: openPrevisitNext) {
            PrevisitPromptView(startTitle: previsitSession.hasDraft ? "이어서 작성하기" : nil,
                               onStart: { closePrevisitPrompt(then: .write) },
                               onRecords: { closePrevisitPrompt(then: .letters) },
                               onClose: { showsPrevisitPrompt = false },
                               onDiscard: previsitSession.hasDraft ? { showsPrevisitDiscard = true } : nil)
                .alert("작성 내용을 지울까요?", isPresented: $showsPrevisitDiscard) {
                    Button("유지하기", role: .cancel) { }
                    Button("지우기", role: .destructive) { previsitSession.discard() }
                } message: {
                    Text("선택한 기록과 편지, 기분을 모두 지워요.")
                }
        }
        .fullScreenCover(isPresented: $showsPrevisit, onDismiss: { previsitSession.pause(); openPrevisitNext() }) {
            NavigationStack { previsit(previsitSession) }
        }
        // Figma 07: 기록을 지우면 들어왔던 바텀시트로 돌아가 위에 안내를 띄웁니다
        .onChange(of: previsitLetters.notice) { _, notice in
            guard notice == .deleted else { return }
            path.removeAll()
            if showsPrevisit { previsitNext = .prompt; showsPrevisit = false } else { showsPrevisitPrompt = true }
        }
        .overlay(alignment: .top) {
            if previsitLetters.notice == .deleted {
                PrevisitToast(message: PrevisitLetterViewModel.Notice.deleted.message)
                    .padding(.top, 8)
            }
        }
        .onAppear { updateHomeContext() }
        .onChange(of: isHomeVisible) { updateHomeContext() }
        .onChange(of: scenePhase) { updateHomeContext() }
        .onDisappear { onHomeContextChange(false, false) }
    }

    private var isHomeVisible: Bool { tab == .home && path.isEmpty && !showsPrevisit && !showsPrevisitPrompt }

    private enum PrevisitNext { case write, letters, prompt }

    private func closePrevisitPrompt(then next: PrevisitNext) {
        previsitNext = next
        showsPrevisitPrompt = false
    }

    private func open(_ deepLink: DeepLink) {
        switch deepLink {
        case .careCall(let autoStartVoice):
            showsPrevisit = false

            tab = .home
            path = [.symptom(autoStartVoice: autoStartVoice)]
        case .painRecord:
            showsPrevisit = false

            tab = .home
            path = [.pain]
        case .previsit:
            tab = .home
            previsitSession.start()
            showsPrevisit = true
        }

        router.pendingDeepLink = nil
    }

    private func openPrevisitNext() {
        if let deepLink = router.pendingDeepLink {
            previsitNext = nil
            open(deepLink)
            return
        }
        switch previsitNext {
        case .write:
            previsitSession.start()
            showsPrevisit = true
        case .letters: path.append(.previsitLetters)
        case .prompt: showsPrevisitPrompt = true
        case nil: break
        }
        previsitNext = nil
    }
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
                        NotificationSettingsView(viewModel: NotificationSettingsViewModel.preview())
                    }
                )
            }
        )
    }
}

#Preview { PatientFlowView.preview()
    .environment(AppRouter())
}
#endif
