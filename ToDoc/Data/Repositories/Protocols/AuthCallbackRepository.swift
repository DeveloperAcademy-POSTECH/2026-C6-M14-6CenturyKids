import Foundation

/// 이메일 링크를 실제 인증 세션으로 교환하는 연결점입니다.
/// URL 주소/앱 링크 설정이 미정이므로 현재 제품에는 구현체를 주입하지 않습니다.
/// 구현체는 URL의 문자열만 보고 성공하면 안 됩니다. SDK/서버가 확인한 recovery 흐름에서만
/// 사용자 ID를 반환하고, 만료·잘못된 링크·일반 로그인 링크는 오류로 거절해야 합니다.
protocol AuthCallbackRepository {
    func recoverPasswordSession(from url: URL) async throws -> UUID
}
