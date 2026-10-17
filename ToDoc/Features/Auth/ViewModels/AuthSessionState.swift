import Foundation
import Observation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

/// 화면들이 공유하는 '확인된 환자'와 요청 진행 상태입니다. Repository를 호출하는 Service가 아닙니다.
/// 로그인/가입/재설정이 같은 인증 SDK를 사용하므로 한 번에 하나의 작업만 세션을 바꿉니다.
@MainActor @Observable final class AuthSessionState {
    var patient: Patient?
    private(set) var isBusy = false
    @ObservationIgnored private var owner: UUID?

    func begin() -> UUID? {
        guard owner == nil else { return nil }
        let token = UUID()
        owner = token
        isBusy = true
        return token
    }
    /// 화면을 닫아도 네트워크 요청이 끝나기 전에는 잠금을 풀지 않습니다.
    /// 그렇지 않으면 오래된 로그인 응답이 새 로그인 세션을 덮을 수 있습니다.
    func finish(_ token: UUID) {
        guard owner == token else { return }
        owner = nil
        isBusy = false
    }
}
