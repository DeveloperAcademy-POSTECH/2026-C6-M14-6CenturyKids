import Foundation

/// 가입 당시 실제로 보여 준 약관의 버전과 사용자의 선택을 저장하는 계약입니다.
/// 구현체는 팀원이 DB 정책에 맞춰 제공합니다. 화면에서 체크했다고 저장된 것으로 취급하지 않습니다.
/// 같은 userID + version의 재시도는 중복 행을 만들지 않는 upsert로 구현해야 합니다.
protocol SignupConsentRepository {
    func saveConsent(userID: UUID, version: String, acceptedTermIDs: [String], acceptedAt: Date) async throws
}
