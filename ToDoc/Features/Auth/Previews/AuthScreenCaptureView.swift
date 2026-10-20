#if DEBUG
import SwiftUI

/// 팀원이 서버 계정 없이 화면을 재현하고 PR 이미지를 찍는 개발 전용 진입점입니다.
/// Xcode Run Arguments에 --auth-preview login 처럼 넣습니다. Release에는 이 코드가 포함되지 않습니다.
/// 모든 Repository가 nil이며 약관·완료·복구 상태는 화면 확인용 예시입니다. 실제 인증의 검증 근거가 아닙니다.
@MainActor struct AuthScreenCaptureView: View {
    enum Screen: String { case onboarding, intro, login, signup, terms, patient, review, completion, reset, recovery }
    static var requestedScreen: Screen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--auth-preview"), arguments.indices.contains(index + 1) else { return nil }
        return Screen(rawValue: arguments[index + 1])
    }
    @State private var flow: AuthFlowViewModel
    private let screen: Screen
    private let largeText = ProcessInfo.processInfo.arguments.contains("--auth-preview-large-text")

    init(screen: Screen) {
        self.screen = screen
        let flow = AuthFlowViewModel()
        switch screen {
        case .onboarding: break
        case .intro: flow.onboarding.selectPage(1)
        case .login:
            flow.open(.login)
            flow.login.state.email = "preview@example.com"
            flow.login.state.remembersLogin = true
        case .reset: flow.open(.passwordReset)
        case .recovery:
            flow.open(.passwordReset)
            flow.reset.state.isRecoveryReady = true
            // 표시 상태만 지정한 예시이므로 실제 저장 버튼은 제공하지 않습니다.
            flow.reset.state.onSubmit = nil
        default:
            flow.open(.signup)
            let state = flow.signup.state
            switch screen {
            case .terms: state.step = .terms
            case .patient: state.step = .patientInfo
            case .review: state.step = .review
            case .completion: state.step = .completion
            default: break
            }
            if screen == .patient || screen == .review || screen == .completion {
                state.name = "홍길동"; state.email = "preview@example.com"
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                state.birthday = calendar.date(from: DateComponents(year: 1990, month: 1, day: 15))
                state.sex = .female; state.cancerType = .lung; state.stage = .known(.stage1)
            }
        }
        _flow = State(initialValue: flow)
    }

    var body: some View {
        Group {
            if screen == .onboarding || screen == .intro { OnboardingView(model: flow) }
            else { NavigationStack { AuthFlowView(model: flow) } }
        }
        .dynamicTypeSize(largeText ? .accessibility3 : .large)
        .frame(maxWidth: largeText ? 320 : .infinity)
        .frame(maxWidth: .infinity)
        .background(.white)
    }
}
#endif
