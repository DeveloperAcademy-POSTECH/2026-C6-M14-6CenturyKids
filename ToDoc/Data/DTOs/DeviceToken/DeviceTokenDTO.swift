//
//  DeviceTokenDTO.swift
//  ToDoc
//
//  Created by 앤디 on 10/16/26.
//

import Foundation

struct DeviceTokenDTO: Codable {
    let userId: UUID
    let installationId: String
    let tokenType: DeviceTokenType
    let token: String
    let platform: String?
    let environment: String
}

extension DeviceTokenDTO {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case installationId = "installation_id"
        case tokenType = "token_type"
        case token = "token"
        case platform = "platform"
        case environment
    }
}
