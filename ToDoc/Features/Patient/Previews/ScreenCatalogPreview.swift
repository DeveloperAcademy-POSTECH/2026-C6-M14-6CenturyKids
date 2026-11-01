#if DEBUG
import SwiftUI

/// Xcode Canvas에서만 사용하는 화면 모음. 앱 실행 경로에서는 생성하지 않습니다.
struct ScreenCatalogPreview: View {
    enum Screen: String, CaseIterable {
        case voice = "증상 자동 음성", noPresent = "증상 0건 · 표시 항목 없음"
        case summary = "증상 요약", noPresentSummary = "증상 요약 · 표시 항목 없음"
        case onboarding = "온보딩", login = "로그인", signup = "회원가입", reset = "비밀번호 재설정"
        case home = "홈", pain = "통증 입력", incoming = "케어콜 수신", conversation = "증상 입력"
        case records = "기록 목록", painDetail = "통증 상세", painWeekDetail = "통증 상세 · 주", symptomDetail = "증상 상세", symptomWeekDetail = "증상 상세 · 주"
        case settings = "설정", personal = "개인정보", cancer = "암종", stage = "병기", hospital = "의사 연결"
        case notifications = "알림", notificationSettings = "알림 설정"
    }
    @State private var screen: Screen = .summary
    @State private var signup = SignupScreenState()
    @State private var personal = PersonalInfoScreenState()
    @State private var cancer = DiagnosisScreenState()
    @State private var stage = DiagnosisScreenState()
    @State private var hospital = previewHospital()
    @State private var notificationSettingsViewModel = NotificationSettingsViewModel()
    var body: some View {
        VStack(spacing: 0) {
            Text("화면 예시 · 실제 인증/조회/저장 없음").font(.caption).padding(8)
            Picker("화면", selection: $screen) {
                ForEach(Screen.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            if screen == .signup {
                Picker("가입 단계", selection: $signup.step) {
                    ForEach(SignupStep.allCases, id: \.rawValue) { Text(String(describing: $0)).tag($0) }
                }.pickerStyle(.menu)
            }
            NavigationStack { destination }.id(screen)
        }
    }
    @ViewBuilder private var destination: some View {
        switch screen {
        case .onboarding: OnboardingView(viewModel: AuthFlowViewModel(session: AuthSessionState()))
        case .login: AuthFlowView(viewModel: AuthFlowViewModel(session: AuthSessionState()))
        case .signup: SignupFormView(state: signup, onBack: {}, onLogin: {})
        case .reset: PasswordResetView()
        case .home: HomeView(state: homeState(), onSelect: { _ in })
        case .pain: PainRecordView.preview()
        case .incoming: CareCallIncomingView(canAnswer: true, onAnswer: {}, onEnd: {}, onPostpone: {}, onSwitchToText: {})
        case .conversation: SymptomRecordView(state: conversationState())
        case .summary: SymptomSummaryView(state: .init(record: symptomRecord()))
        case .noPresentSummary: SymptomSummaryView(state: .init(record: symptomRecord(includesPresent: false)))
        case .records: RecordsView(snapshot: .init(pain: .init(averageBefore: 7, averageAfter: 0, difference: 7), symptom: .init(presentCount: 1, types: [.constipation])), state: .loaded)
        case .voice: SymptomRecordView(state: voiceState())
        case .noPresent: SymptomRecordDetailView(state: symptomDetailState(includesPresent: false))
        case .painDetail: PainRecordDetailView(state: detailState(.pain))
        case .painWeekDetail: PainRecordDetailView(state: weekState(.pain))
        case .symptomDetail: SymptomRecordDetailView(state: detailState(.symptom))
        case .symptomWeekDetail: SymptomRecordDetailView(state: weekState(.symptom))
        case .settings:
            SettingsView(
                state: settingsState(),
                notificationSettings: {
                    NotificationSettingsView(viewModel: notificationSettingsViewModel)
                }
            )
        case .personal: PersonalInfoEditView(state: personal)
        case .cancer: CancerTypeEditView(state: cancer)
        case .stage: CancerStageEditView(state: stage)
        case .hospital: HospitalConnectionView(state: hospital)
        case .notifications: NotificationView(state: notificationState())
        case .notificationSettings:
            NotificationSettingsView(viewModel: notificationSettingsViewModel)
        }
    }
    private func homeState() -> HomeScreenState {
        let state = HomeScreenState()
        state.doctor = .loaded(.linked(.init(id: UUID(), name: "예시 의료진")))
        state.greeting = HomeGreeting.all[0]
        state.showsUnreadBadge = true
        return state
    }
    private func conversationState() -> SymptomScreenState {
        let state = SymptomScreenState()
        state.question = .init(id: UUID(), text: "오늘 불편했던 증상이 있나요?", guidance: "화면 예시 질문이에요.", progress: 0.2, input: .text)
        return state
    }
    private func voiceState() -> SymptomScreenState {
        let state = conversationState()
        state.mode = .voice; state.isListening = true; state.transcript = "어제부터 양쪽 손이 저렸어요."
        return state
    }
    private func symptomRecord(includesPresent: Bool = true) -> SymptomRecordDisplay {
        .init(id: UUID(), recordedDate: .now, symptoms: [
            .init(id: UUID(), symptomType: .constipation, presence: .present, rawLocationText: "아랫배", durationMinutes: 30,
                  occurrenceCount: 2, detail: "[검토 필요] 어제부터 두세 번 불편했어요. (화면 예시)"),
            .init(id: UUID(), symptomType: .nauseaVomiting, presence: .absent, detail: "오늘은 없었어요."),
            .init(id: UUID(), symptomType: .rashItching, presence: .unknown, detail: "[검토 필요] 잘 모르겠어요.")
        ].filter { includesPresent || $0.presence != .present })
    }
    private func detailState(_ kind: RecordOverviewKind) -> RecordDetailScreenState {
        let state = RecordDetailScreenState(kind: kind)
        let date = Date()
        state.loadState = .loaded; state.days = [date]; state.periodLabel = "오늘 · 예시"; state.rangeLabel = "화면 확인용 데이터"
        if kind == .pain {
            state.content = .pain(.init(averageDifference: 7, days: [], records: [
                .init(id: UUID(), recordedDate: date, painBefore: 7, painAfter: 0)
            ]))
        } else {
            state.canEdit = true
            state.content = .symptom(.init(symptoms: [.init(type: .constipation, weight: 1), .init(type: .diarrhea, weight: 1)],
                                           records: [symptomRecord()]))
        }
        return state
    }
    private func weekState(_ kind: RecordOverviewKind) -> RecordDetailScreenState {
        let state = detailState(kind)
        let calendar = state.calendar
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        state.period = .week; state.periodLabel = "이번 주 · 예시"
        state.days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        if kind == .pain {
            let scores: [(Double, Double)?] = [(10, 0), (7, 4), (8, 3), nil, (7, 4), (8, 1), (7, 4)]
            state.content = .pain(.init(averageDifference: 3, days: zip(state.days, scores).compactMap { date, score in
                score.map { .init(date: date, averageBefore: $0.0, averageAfter: $0.1) }
            }, records: nil))
        } else {
            // 주: 증상마다 '있음'으로 나타난 날 수 (1위 동률 예시)
            let days: [(SymptomType, Double)] = [(.nauseaVomiting, 3), (.numbness, 3), (.diarrhea, 2), (.oralPain, 1), (.rashItching, 1)]
            state.content = .symptom(.init(symptoms: days.map { .init(type: $0.0, weight: $0.1) }, records: [symptomRecord()]))
        }
        return state
    }
    private func symptomDetailState(includesPresent: Bool) -> RecordDetailScreenState {
        let state = detailState(.symptom)
        let record = symptomRecord(includesPresent: includesPresent)
        state.content = .symptom(.init(symptoms: [], records: [record]))
        return state
    }
    private func settingsState() -> SettingsScreenState {
        let state = SettingsScreenState()
        state.profile = .init(name: "예시 환자", cancerName: "폐암", stageName: "2기", hospitalName: "예시 병원", doctorName: "예시 의료진")
        state.loadState = .loaded
        return state
    }
    private func notificationState() -> NotificationScreenState {
        let state = NotificationScreenState(); state.loadState = .loaded
        state.sections = [.init(id: "today", title: "오늘", hasUnread: true, items: [
            .init(id: UUID(), title: "주치의 메시지", body: "기록을 확인했어요. (화면 예시)", timeLabel: "오전 9:00", isRead: false)
        ])]
        return state
    }
    private static func previewHospital() -> HospitalConnectionScreenState {
        let state = HospitalConnectionScreenState()
        state.hasLoaded = true
        state.code = "A12B34"
        state.doctor = .init(hospitalName: "예시 병원", name: "예시 담당의")
        state.candidate = .init(hospitalName: "다른 예시 병원", name: "예시 의료진")
        return state
    }
}
#Preview("전체 화면 모음 · 예시 전용") { ScreenCatalogPreview() }
#endif
