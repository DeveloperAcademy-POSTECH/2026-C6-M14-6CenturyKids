//
//  SupabaseAuthRepository.swift
//  ToDoc
//
//  Created by 앤디 on 10/16/26.
//

import Foundation
import Supabase

final class SupabaseAuthRepository: AuthRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func signUp(email: String, password: String) async throws -> UUID {
        let response = try await client.auth.signUp(email: email, password: password)
        
        return response.user.id
    }
    
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws {
        try await client.auth.resend(email: email, type: .signup, emailRedirectTo: url)
    }
    
    func signIn(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(email: email, password: password)
        
        return session.user.id
    }
    
    // 앱에서 랜덤 nonce를 발급하여 해시 처리한 값을 Apple 로그인에 넘겨야 함
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        return session.user.id
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func getCurrentUserEmail() async throws -> String? {
        let user = try await client.auth.user()
        return user.email
    }
    
    func getCurrentUserId() async throws -> UUID {
        let user = try await client.auth.user()
        
        return user.id
    }
    
    func isSignedIn() -> Bool {
        client.auth.currentUser != nil
    }
    
    // 비밀번호 아는 상태에서 변경 요청
    func requestPasswordChangeVerification() async throws {
        try await client.auth.reauthenticate()
    }
    
    // 비밀번호 모르는 상태에서 초기화 요청
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: url)
    }
    
    // 비밀번호 업데이트
    func updatePassword(to newPassword: String, nonce: String?) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword, nonce: nonce))
    }
    
    func deleteAccount() async throws {
        let session = try await client.auth.session
        
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ]
            )
        )
        
        try await client.auth.signOut(scope: .global)
    }
}
