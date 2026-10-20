import Foundation

/// '다음 실행에서도 로그인할지'만 저장하는 설정입니다. 비밀번호나 인증 토큰은 저장하지 않습니다.
/// 토큰의 보관/갱신은 기존 AuthRepository와 인증 SDK가 담당합니다.
/// 앱 DI에서만 UserDefaults.standard를 전달하고, Preview/테스트는 기본 메모리 값을 사용합니다.
@MainActor final class AuthLoginPreference {
    private let defaults: UserDefaults?
    private let key = "auth.remembersSuccessfulLogin"
    private var memoryValue = false

    init(defaults: UserDefaults? = nil) { self.defaults = defaults }

    var isEnabled: Bool {
        get { defaults?.bool(forKey: key) ?? memoryValue }
        set {
            memoryValue = newValue
            defaults?.set(newValue, forKey: key)
        }
    }
}
