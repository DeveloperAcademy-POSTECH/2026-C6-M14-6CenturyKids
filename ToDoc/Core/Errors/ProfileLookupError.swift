/// 인증된 사용자의 필수 프로필 조회 결과가 없을 때 사용합니다.
/// 입력값 검증, 네트워크 실패, 환자의 의사 미연결 상태와 구분합니다.
nonisolated public enum ProfileLookupError: Error, Equatable, Sendable {
    case userNotFound
    case patientNotFound
    case doctorNotFound
}
