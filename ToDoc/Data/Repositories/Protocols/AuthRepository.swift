//
//  AuthRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol AuthRepository {
    func signUp(
        email: String,
        password: String
    ) async throws -> UUID
    
    func signIn(
        email: String,
        password: String
    ) async throws -> UUID
    
    func signOut() async throws
    
    func getCurrentUserId() async throws -> UUID?
    
    func isSignedIn() async throws -> Bool
    
    func resetPassword(
        email: String
    ) async throws
}
