#if DEBUG
import SwiftUI

/// 개발 전용 목록. 실제 Repository·음성 엔진·저장을 호출하지 않습니다.
/// 최신 6개 섹션과 기존 인증/온보딩을 한 Canvas에서 비교합니다.
struct DesignSystemAuditPreview: View {
    @State private var selection: String
    private let showsPicker: Bool
    private let largeText: Bool

    init(initialScene: String = "tokens", showsPicker: Bool = true, largeText: Bool = false) {
        _selection = State(initialValue: initialScene)
        self.showsPicker = showsPicker
        self.largeText = largeText
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsPicker {
                Picker("디자인 시스템 검증 화면", selection: $selection) {
                    ForEach(DesignSystemAuditScene.all) { scene in
                        Text(scene.title).tag(scene.id)
                    }
                }.pickerStyle(.menu).appTextStyle(.caption)
            }
            (DesignSystemAuditScene.all.first { $0.id == selection } ?? DesignSystemAuditScene.all[0]).content()
                .id(selection)
                .dynamicTypeSize(largeText ? .accessibility3 : .large)
                .frame(maxWidth: largeText ? 320 : .infinity)
                .frame(maxWidth: .infinity)
        }
        .background(AppColors.surface)
        .preferredColorScheme(.light)
    }
}

/// AnyView는 서로 다른 화면을 열거하는 DEBUG 카탈로그에만 사용합니다.
@MainActor struct DesignSystemAuditScene: Identifiable {
    let id: String
    let title: String
    let content: () -> AnyView

    static var all: [Self] {
        var scenes = [Self(id: "tokens", title: "공통 스타일", content: { AnyView(DesignTokensPreview()) })]
        scenes.append(Self(id: "shared-controls", title: "공통 입력·진행률", content: { AnyView(AppComponentsPreview()) }))
        let authScreens: [AuthScreenCaptureView.Screen] = [.login, .reset, .recovery]
        scenes += authScreens.map { screen in
            Self(id: "auth-\(screen.rawValue)", title: "인증 · \(screen.rawValue)", content: { AnyView(AuthScreenCaptureView(screen: screen)) })
        }
        scenes += SignupStep.allCases.map { step in
            Self(id: "signup-\(step)", title: "가입 · \(step)", content: { AnyView(DesignSystemSignupFixture(step: step)) })
        }
        scenes += (0...4).map { page in
            Self(id: "onboarding-\(page)", title: "온보딩 · \(page)", content: {
                let flow = AuthFlowViewModel()
                flow.onboarding.selectPage(page)
                return AnyView(OnboardingView(model: flow))
            })
        }
        scenes += PrevisitSectionPreview.Screen.allCases.map { screen in
            Self(id: "previsit-\(screen.rawValue)", title: "진료 전 · \(screen.rawValue)", content: { AnyView(PrevisitSectionPreview(initialScreen: screen)) })
        }
        scenes += NotificationSectionPreview.Screen.allCases.map { screen in
            Self(id: "notification-\(screen.rawValue)", title: "알림 · \(screen.rawValue)", content: { AnyView(NavigationStack { NotificationSectionPreview(initialScreen: screen) }) })
        }
        scenes += CareCallVoicePhase.allCases.map { phase in
            Self(id: "voice-\(phase.rawValue)", title: "케어콜 음성 · \(phase.title)", content: {
                if phase == .loading { return AnyView(SymptomSummaryLoadingView()) }
                return AnyView(CareCallVoiceSectionPreview(initialPhase: phase, showsControls: false))
            })
        }
        scenes += CareCallManualStep.allCases.map { step in
            Self(id: "manual-\(step.rawValue)", title: "케어콜 수동 · \(step.title)", content: { AnyView(CareCallManualSectionPreview(initialStep: step, showsControls: false)) })
        }
        scenes += PainSectionPreviewScene.allCases.enumerated().map { index, scene in
            Self(id: "pain-\(index)", title: "통증 · \(scene.rawValue)", content: { AnyView(PainSectionPreview(scene: scene, showsScenePicker: false)) })
        }
        scenes += MyPageSectionPreview.Screen.allCases.enumerated().map { index, screen in
            Self(id: "settings-\(index)", title: "설정 · \(screen.rawValue)", content: { AnyView(MyPageSectionPreview(initialScreen: screen, showsControls: false)) })
        }
        scenes.append(Self(id: "conversation", title: "케어콜 전체 흐름", content: { AnyView(CareCallConversationPreview()) }))
        scenes.append(Self(id: "licenses", title: "라이선스", content: { AnyView(NavigationStack { OpenSourceLicensesView() }) }))
        scenes.append(Self(id: "notification-settings", title: "알림 설정 · 디자인 대기", content: { AnyView(NavigationStack { NotificationSettingsView() }) }))
        return scenes
    }
}

private struct DesignSystemSignupFixture: View {
    @State private var state: SignupScreenState
    init(step: SignupStep) {
        let state = SignupScreenState()
        state.step = step
        state.name = "홍길동"
        state.email = "preview@example.com"
        state.connection = .init(hospitalName: "세명기독병원", department: "종양내과", doctorName: "김학로")
        state.birthday = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 15))
        state.sex = .female
        state.cancerType = .lung
        state.stage = .known(.stage1)
        _state = State(initialValue: state)
    }
    var body: some View {
        NavigationStack { SignupFormView(state: state, onBack: {}, onLogin: {}) }
    }
}

#Preview("전체 화면 · 디자인 시스템 검증") { DesignSystemAuditPreview() }
#Preview("좁은 폭 · 큰 글자", traits: .fixedLayout(width: 320, height: 800)) {
    DesignSystemAuditPreview(initialScene: "manual-duration", largeText: true)
}
#endif
