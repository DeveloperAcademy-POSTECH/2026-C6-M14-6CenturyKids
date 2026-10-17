//
//  DependencyContainer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

@MainActor final class DependencyContainer {
    // SupabaseClient 보관하는 객체
    let supabaseProvider: SupabaseClientProvider
    
    init(configuration: SupabaseConfiguration) {
        supabaseProvider = SupabaseClientProvider(
            configuration: configuration
        )
    }

    /// 팀원이 Repository를 완성하면 이 함수의 인자로 전달합니다. VM/화면을 다시 만들 필요가 없습니다.
    /// 현재 기본값 nil은 의도적인 미연결입니다. 실제 DB 저장 성공을 흉내 내는 객체를 넣지 않습니다.
    func makeAuthFlow(configuration: AuthConfiguration = .init(),
                      users: (any UserRepository)? = nil,
                      patients: (any PatientRepository)? = nil,
                      doctors: (any DoctorRepository)? = nil,
                      hospitals: (any HospitalRepository)? = nil,
                      consents: (any SignupConsentRepository)? = nil,
                      callbacks: (any AuthCallbackRepository)? = nil) -> AuthFlowViewModel {
        let auth = SupabaseAuthRepository(client: supabaseProvider.client, signupRedirectURL: configuration.redirectURL)
        return AuthFlowViewModel(
            repositories: .init(auth: auth, users: users, patients: patients,
                                doctors: doctors, hospitals: hospitals, consents: consents, callbacks: callbacks),
            configuration: configuration
        )
    }
}
