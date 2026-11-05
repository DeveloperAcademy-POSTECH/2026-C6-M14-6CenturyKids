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
    private let supabaseURL: URL
    private let publishableKey: String
    
    init(client: SupabaseClient, configuration: SupabaseConfiguration) {
        self.client = client
        self.supabaseURL = configuration.url
        self.publishableKey = configuration.publishableKey
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
    
    private func makeKakaoSignInRequest(idToken: String) throws -> URLRequest {
        let url = supabaseURL
            .appendingPathComponent("auth/v1/token")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "id_token")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = KakaoSignInRequest(provider: "kakao", idToken: idToken)
        request.httpBody = try JSONEncoder().encode(body)
        
        return request
    }
    
    private func requestKakaoSession(idToken: String) async throws -> KakaoSignInResponse {
        let request = try makeKakaoSignInRequest(idToken: idToken)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "KakaoSignIn",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Supabase 로그인 요청에 실패했어요. HTTP \(httpResponse.statusCode)"]
            )
        }
        
        return try JSONDecoder().decode(KakaoSignInResponse.self, from: data)
    }
    
    func signInWithKakao(idToken: String) async throws -> UUID {
        let response = try await requestKakaoSession(idToken: idToken)
        
        let session = try await client.auth.setSession(accessToken: response.accessToken, refreshToken: response.refreshToken)
        
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
    
    // 재설정 메일의 인증코드 확인 (성공하면 비밀번호를 바꿀 수 있는 세션이 생김)
    func verifyPasswordResetCode(email: String, code: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
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
    
    func withdrawAppleAccount(authorizationCode: String) async throws {
        let session = try await client.auth.session
        
        try await client.functions.invoke(
            "delete-apple-account",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ],
                body: [
                    "authorizationCode": authorizationCode
                ]
            )
        )
        
        try await client.auth.signOut(scope: .global)
    }
    
    func withdrawKakaoAccount() async throws {
        let session = try await client.auth.session

        try await client.functions.invoke(
            "delete-kakao-account",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ]
            )
        )

        try await client.auth.signOut(scope: .global)
    }
    
    func getSignUpProvider() async throws -> String? {
        let user = try await client.auth.user()
        
        return user.appMetadata["provider"]?.stringValue
    }
}

private struct KakaoSignInRequest: Encodable {
    let provider: String
    let idToken: String
    
    enum CodingKeys: String, CodingKey {
        case provider
        case idToken = "id_token"
    }
}

private struct KakaoSignInResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
