//
//  AuthRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol AuthRepository {
    func signUp(email: String, password: String) async throws -> UUID
    
    func resendSignUpConfirmationEmail(to email: String, redirectTo url: URL?) async throws
    
    func signIn(email: String, password: String) async throws -> UUID
    
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID
    
    func signOut() async throws
    
    func getCurrentUserEmail() async throws -> String?

    func getCurrentUserId() async throws -> UUID
    
    func isSignedIn() -> Bool
    
    func requestPasswordChangeVerification() async throws
    
    func sendPasswordResetEmail(to email: String, redirectTo url: URL?) async throws
    
    func verifyPasswordResetCode(email: String, code: String) async throws
    
    func updatePassword(to newPassword: String, nonce: String?) async throws
    
    func deleteAccount() async throws

    func withdrawAppleAccount(authorizationCode: String) async throws
    
    func getSignUpProvider() async throws -> String?
}
