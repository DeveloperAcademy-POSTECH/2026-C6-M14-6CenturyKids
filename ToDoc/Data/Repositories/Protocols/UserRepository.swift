//
//  UserRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation

protocol UserRepository {
    func save(user: User) async throws
    
    func findById(_ id: UUID) async throws -> User?

    func findByName(
        _ name: String
    ) async throws -> [User]
}
