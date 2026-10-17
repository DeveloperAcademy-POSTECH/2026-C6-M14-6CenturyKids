//
//  UserRepository.swift
//  ToDoc
//
//  Created by 허지우 on 10/10/26.
//

import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

protocol UserRepository: Repository where Entity == User {
    func save(user: User) async throws

    func findByEmail(
        _ email: String
    ) async throws -> User?

    func findByName(
        _ name: String
    ) async throws -> [User]
}
