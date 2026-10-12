//
//  DeviceTokenRepository.swift
//  ToDoc
//

import Foundation

protocol DeviceTokenRepository {
    func saveToken(
        userId: UUID,
        _ token: String
    ) async throws

    func deleteToken(
        _ token: String
    ) async throws
}
