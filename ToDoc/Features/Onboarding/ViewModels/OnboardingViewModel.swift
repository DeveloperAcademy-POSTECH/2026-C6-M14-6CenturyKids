import Foundation
import Observation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

@MainActor @Observable final class OnboardingViewModel {
    var page = 0
    var isRestoring = false
    var errorMessage: String?
    let repositories: AuthRepositories
    let session: AuthSessionState
    init(repositories: AuthRepositories, session: AuthSessionState) {
        self.repositories = repositories; self.session = session
    }
    /// View는 페이지를 표시하고, 이동 가능한 범위는 ViewModel이 결정합니다.
    func selectPage(_ page: Int) { self.page = min(max(page, 0), 4) }

    /// 저장된 인증 정보가 있더라도 서버 사용자와 DB 환자 정보를 다시 확인합니다.
    /// 인증 SDK의 '캐시에 사용자가 있음'만으로 제품 화면에 진입하지 않습니다.
    func restoreSession() async {
        guard !isRestoring, session.patient == nil, let auth = repositories.auth else { return }
        guard auth.isSignedIn() else { return }
        guard let users = repositories.users, let patients = repositories.patients else {
            errorMessage = "저장된 로그인 정보를 확인하려면 사용자·환자 정보 연결이 필요해요."
            return
        }
        guard let token = session.begin() else { return }
        isRestoring = true; errorMessage = nil
        defer { isRestoring = false; session.finish(token) }
        do {
            let id = try await auth.getCurrentUserId()
            guard let user = try await users.findById(id), user.id == id,
                  let patient = try await patients.findById(id), patient.user.id == id else {
                throw AuthFlowError("가입 정보가 아직 완성되지 않았어요. 회원가입을 이어서 진행해 주세요.")
            }
            try Task.checkCancellation()
            session.patient = patient
        } catch {
            session.patient = nil
            errorMessage = (error as? AuthFlowError)?.message ?? "이전 로그인을 확인하지 못했어요. 다시 로그인해 주세요."
            do { try await auth.signOut() }
            catch { errorMessage = "이전 인증 상태를 정리하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요." }
        }
    }
}
