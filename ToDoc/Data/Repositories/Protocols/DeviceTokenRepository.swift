//
//  DeviceTokenRepository.swift
//  ToDoc
//

import Foundation

protocol DeviceTokenRepository {
    func save(token: DeviceTokenDTO) async throws

    func delete(token: DeviceTokenDTO) async throws
}
