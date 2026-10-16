//
//  DeviceTokenRepository.swift
//  ToDoc
//

import Foundation

protocol DeviceTokenRepository {
    func save(
        token: String,
        for userId: UUID
    ) async throws

    func delete(
        token: String
    ) async throws
}
