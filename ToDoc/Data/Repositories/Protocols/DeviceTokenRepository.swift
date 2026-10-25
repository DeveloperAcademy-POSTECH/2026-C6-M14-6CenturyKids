//
//  DeviceTokenRepository.swift
//  ToDoc
//

import Foundation

protocol DeviceTokenRepository {
    func save(token: DeviceTokenDTO) async throws

    func removeToken(userId: UUID, installationId: String) async throws
}
